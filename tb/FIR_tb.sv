`timescale 1ns/1ps
// Simple self-checking testbench for FIR.sv.
// Inputs change on the falling edge, the FIR takes them in on the rising edge,
// and the checks run on the next falling edge. Any wrong value prints FAIL.
// Vivado: set FIR_tb as top and use "run all". The last line says TEST PASSED or TEST FAILED.
module FIR_tb;

    logic CLK = 0;
    always #5 CLK = ~CLK;

    logic RSTn, FIREN, CENWR, COMMIT;
    logic signed [3:0]  x_in;
    logic [3:0]         CADDR;
    logic signed [7:0]  CDATA;
    logic signed [15:0] y_out;
    logic               BUSY, DONE;
    logic [15:0]        SREADY;

    FIR dut (.CLK(CLK), .RSTn(RSTn), .FIREN(FIREN), .x_in(x_in), .y_out(y_out), .BUSY(BUSY),
             .CENWR(CENWR), .CADDR(CADDR), .CDATA(CDATA), .SREADY(SREADY), .COMMIT(COMMIT), .DONE(DONE));

    int errors = 0;
    int dones  = 0;                                  // number of DONE pulses seen
    always @(posedge CLK) #1 if (DONE) dones++;

    logic signed [7:0]  h [2][16];                   // two impulse responses to load
    logic signed [15:0] hold;
    logic [15:0]        mask;

    // ---------------- helpers ----------------
    task automatic tick(input int n);                // wait n clocks
        repeat (n) @(negedge CLK);
    endtask

    task automatic write(input int a, input int d);  // write one shadow value
        CENWR = 1; CADDR = a; CDATA = d;
        @(negedge CLK);
        CENWR = 0;
    endtask

    task automatic commit();                         // 1-clock COMMIT pulse
        COMMIT = 1;
        @(negedge CLK);
        COMMIT = 0;
    endtask

    task automatic load(input int b);                // write all 16 values of impulse response b
        for (int i = 0; i < 16; i++) write(i, h[b][i]);
    endtask

    task automatic reset();                          // reset, then FIREN high
        RSTn = 0; CENWR = 0; COMMIT = 0; x_in = 0;
        tick(2);
        RSTn = 1; FIREN = 1; dones = 0;
    endtask

    task automatic check(input bit ok, input string msg);
        if (!ok) begin
            errors++;
            $display("  FAIL at %0d ns: %s", $time, msg);
        end
    endtask

    // Send x = 1 then zeros: y_out must step through h[b][0..15], one tap per clock.
    task automatic check_impulse(input int b);
        x_in = 1;
        @(negedge CLK);
        x_in = 0;
        for (int k = 0; k < 16; k++) begin
            check(y_out == h[b][k], $sformatf("tap %0d: y_out = %0d, expected %0d", k, y_out, h[b][k]));
            @(negedge CLK);
        end
        check(y_out == 0, "y_out should be back to 0 after the 16 taps");
    endtask

    // ---------------- tests ----------------
    initial begin
        RSTn = 1; FIREN = 0; CENWR = 0; COMMIT = 0; CADDR = 0; CDATA = 0; x_in = 0;
        for (int i = 0; i < 16; i++) begin
            h[0][i] = (i % 2) ? -(i + 1) * 7 : (i + 1) * 7;   // 7, -14, 21, -28 ... all different
            h[1][i] = 100 - 13 * i;                           // 100, 87, 74 ... -95
        end
        @(negedge CLK);

        $display("1. reset clears everything at once, nothing runs while FIREN is low");
        RSTn = 0;
        #1 check(y_out == 0 && BUSY == 0 && DONE == 0 && SREADY == 0, "outputs not 0 straight after reset");
        tick(2);
        RSTn = 1;
        tick(2);
        check(BUSY == 0, "nothing should run while FIREN is low");
        FIREN = 1;
        tick(1);
        check(BUSY == 1, "BUSY should be 1 once FIREN is high");
        check(y_out == 0, "the default impulse response is all zeros");

        $display("2. writes fill SREADY one bit at a time");
        mask = 0;
        for (int i = 0; i < 16; i++) begin
            write(i, h[0][i]);
            mask[i] = 1;
            check(SREADY == mask, $sformatf("SREADY = %h after writing position %0d, expected %h", SREADY, i, mask));
        end
        check(y_out == 0 && DONE == 0, "writing the shadow values must not change the filter");

        $display("3. a 1-clock COMMIT gives DONE for exactly 1 clock and clears SREADY");
        commit();                                    // COMMIT goes in on this clock ...
        tick(1);                                     // ... the commit happens on the next one
        check(DONE == 1, "DONE should be 1 one clock after COMMIT");
        check(BUSY == 0 && y_out == 0 && SREADY == 0, "on the DONE clock: BUSY = 0, y_out = 0, SREADY = 0");
        tick(1);
        check(DONE == 0 && BUSY == 1, "DONE must last only 1 clock, then BUSY goes back to 1");
        tick(5);
        check(dones == 1, "expected exactly one DONE");

        $display("4. impulse response: every value landed on the right tap");
        check_impulse(0);

        $display("5. a commit throws away the old samples (old and new never mix)");
        x_in = 7;
        tick(20);                                    // fill the filter with samples
        load(1);
        commit();
        tick(1);
        check(DONE == 1, "expected the second commit");
        check_impulse(1);                            // right after the commit: only the new taps

        $display("6. COMMIT before all 16 writes waits, then commits by itself");
        reset();
        for (int i = 0; i < 15; i++) write(i, h[0][i]);   // position 15 still missing
        commit();
        tick(2);
        commit();                                    // a second request while waiting: still one commit
        tick(10);
        check(dones == 0, "the commit must wait for the 16th write");
        check(SREADY == 16'h7FFF, "SREADY should show position 15 missing");
        write(15, h[0][15]);
        tick(1);
        check(DONE == 1, "the commit should happen one clock after the 16th write");
        load(1);                                     // a whole new set, but no COMMIT this time
        tick(5);
        check(dones == 1, "nothing may be left waiting: a new set without COMMIT must not commit");

        $display("7. a COMMIT and a write on the exact commit clock are both kept for the next set");
        reset();
        load(0);
        commit();                                    // the commit happens on the next clock ...
        CENWR = 1; CADDR = 3; CDATA = 99; COMMIT = 1;   // ... and these land on that same clock
        tick(1);
        CENWR = 0; COMMIT = 0;
        check(DONE == 1, "expected the commit");
        check(SREADY == 16'h0008, "the write on the commit clock must be kept (SREADY bit 3)");
        h[1][3] = 99;
        for (int i = 0; i < 16; i++) if (i != 3) write(i, h[1][i]);   // finish the next set, no new COMMIT
        tick(2);
        check(dones == 2, "the COMMIT sent on the commit clock must not be lost");
        check_impulse(1);                            // includes the value written on the commit clock

        $display("8. FIREN low: writes and COMMIT are ignored, y_out holds, BUSY and DONE are 0");
        reset();
        load(0);
        commit();
        x_in = 3;
        tick(20);
        hold = y_out;
        FIREN = 0;
        write(5, 55);                                // ignored
        commit();                                    // ignored
        x_in = -5;
        tick(5);
        check(y_out == hold, "y_out must hold while FIREN is low");
        check(BUSY == 0 && DONE == 0, "BUSY and DONE must be 0 while FIREN is low");
        check(SREADY == 0, "a write while FIREN is low must be ignored");
        FIREN = 1;
        tick(2);
        check(BUSY == 1, "the filter must run again once FIREN is high");
        load(1);                                     // a full set without COMMIT
        tick(3);
        check(dones == 1, "the COMMIT sent while FIREN was low must be lost");
        x_in = 0;

        $display("9. a ready commit waits while FIREN is low and runs when it is back; DONE never sticks");
        reset();
        load(0);
        commit();                                    // the commit would happen on the next clock ...
        FIREN = 0;                                   // ... but FIREN is low on it
        tick(5);
        check(dones == 0, "no commit while FIREN is low");
        FIREN = 1;
        tick(1);
        check(DONE == 1, "the waiting commit should run on the first clock with FIREN high");
        FIREN = 0;                                   // drop FIREN on the DONE clock
        tick(1);
        check(DONE == 0, "DONE must not stay high when FIREN drops");
        FIREN = 1;
        tick(2);

        $display("10. reset cancels a waiting COMMIT");
        reset();
        for (int i = 0; i < 15; i++) write(i, h[0][i]);
        commit();
        tick(2);
        reset();
        check(SREADY == 0, "reset must clear SREADY");
        load(0);
        tick(5);
        check(dones == 0, "the cancelled COMMIT must not come back");

        $display("11. the biggest possible sums come out exactly (16 bits is enough)");
        reset();
        for (int i = 0; i < 16; i++) h[0][i] = -128;
        load(0);
        commit();
        x_in = -8;
        tick(20);
        check(y_out == 16384, $sformatf("all -128 with x = -8: y_out = %0d, expected 16384", y_out));
        reset();
        for (int i = 0; i < 16; i++) h[0][i] = 127;
        load(0);
        commit();
        x_in = -8;
        tick(20);
        check(y_out == -16256, $sformatf("all 127 with x = -8: y_out = %0d, expected -16256", y_out));

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED (%0d errors)", errors);
        $finish;
    end

endmodule
