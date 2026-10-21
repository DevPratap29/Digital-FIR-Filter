`timescale 1ns/1ps
// Simple self-checking testbench for FIR.sv.
// Inputs change on the falling edge, the FIR takes them in on the rising edge,
// and the checks run on the next falling edge. Any wrong value prints FAIL.
// Vivado: set FIR_tb as top and use "run all". The last line says TEST PASSED or TEST FAILED.
//
// 1. bandpass pi/4 to 3pi/4 written in random address order, COMMIT comes in the middle of the writes
// 2. the bandpass runs while a lowpass pi/3 is written, then commit and let the lowpass run
// 3. FIREN low: the filter must halt
// 4. reset: everything must go to 0
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

    // The two impulse responses to load: 16-tap Hamming window designs, scaled so the biggest value is 127, then rounded.
    // Same as MATLAB fir1(15,[0.25 0.75]) and fir1(15,1/3), or Python scipy.signal.firwin.
    logic signed [7:0] coef [2][16] = '{
        '{ -1,  3,  7,  -6,  11, -48, -94, 127, 127, -94, -48,  11,  -6,  7,  3, -1 },  // 0: bandpass pi/4 to 3pi/4
        '{  1,  1, -3, -11, -11,  20,  78, 127, 127,  78,  20, -11, -11, -3,  1,  1 }   // 1: lowpass pi/3
    };
    int gain [2];                                    // sum of the 16 values: a constant input x gives y_out = x * gain
    logic signed [15:0] hold;

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

    // Write all 16 values of impulse response b in a random address order.
    // mid = 1: COMMIT is sent after the first 8 writes. (For a different order, give xsim -sv_seed <number>.)
    task automatic load(input int b, input bit mid);
        int order [16];
        int j, t;
        for (int i = 0; i < 16; i++) order[i] = i;
        for (int i = 15; i > 0; i--) begin           // shuffle the addresses
            j = $urandom_range(i);
            t = order[i]; order[i] = order[j]; order[j] = t;
        end
        $write("   address order:");
        for (int i = 0; i < 16; i++) $write(" %0d", order[i]);
        $display("");
        for (int i = 0; i < 16; i++) begin
            if (mid && i == 8) commit();             // COMMIT in the middle of the writes
            write(order[i], coef[b][order[i]]);
        end
    endtask

    task automatic check(input bit ok, input string msg);
        if (!ok) begin
            errors++;
            $display("  FAIL at %0d ns: %s", $time, msg);
        end
    endtask

    // Send x = 1 then zeros: y_out must step through coef[b][0..15], one tap per clock.
    task automatic check_impulse(input int b);
        x_in = 1;
        @(negedge CLK);
        x_in = 0;
        for (int k = 0; k < 16; k++) begin
            check(y_out == coef[b][k], $sformatf("tap %0d: y_out = %0d, expected %0d", k, y_out, coef[b][k]));
            @(negedge CLK);
        end
        check(y_out == 0, "y_out should be back to 0 after the 16 taps");
    endtask

    // ---------------- tests ----------------
    initial begin
        RSTn = 0; FIREN = 0; CENWR = 0; COMMIT = 0; CADDR = 0; CDATA = 0; x_in = 0;
        for (int b = 0; b < 2; b++)
            for (int i = 0; i < 16; i++) gain[b] = gain[b] + coef[b][i];
        tick(2);
        RSTn = 1; FIREN = 1;
        tick(2);

        $display("1. bandpass pi/4 to 3pi/4: random address order, COMMIT in the middle of the writes");
        load(0, 1);
        check(dones == 0, "the commit must wait until all 16 values are written");
        tick(1);
        check(DONE == 1, "DONE should come one clock after the last write");
        check(SREADY == 0, "the commit should clear SREADY");
        check_impulse(0);                            // every value landed on the right tap

        $display("2. the bandpass runs while the lowpass pi/3 is written, then commit and run the lowpass");
        x_in = 7;
        tick(20);                                    // let the bandpass run
        check(y_out == 7 * gain[0], $sformatf("bandpass: y_out = %0d, expected %0d", y_out, 7 * gain[0]));
        load(1, 0);                                  // the bandpass keeps running during these writes
        check(y_out == 7 * gain[0], "writing the shadow values must not change the running filter");
        check(dones == 1, "a full set without COMMIT must not commit by itself");
        commit();
        tick(1);
        check(DONE == 1, "DONE should come one clock after COMMIT");
        check(y_out == 0, "the commit throws away the old samples (old and new never mix)");
        check_impulse(1);                            // right after the commit: only the new taps
        x_in = 7;
        tick(20);                                    // let the lowpass run
        check(y_out == 7 * gain[1], $sformatf("lowpass: y_out = %0d, expected %0d", y_out, 7 * gain[1]));

        $display("3. FIREN low: the filter must halt");
        hold = y_out;
        FIREN = 0;
        x_in = -8;                                   // a halted filter must ignore this
        tick(10);
        check(y_out == hold, "y_out must hold while FIREN is low");
        check(BUSY == 0, "BUSY must be 0 while FIREN is low");

        $display("4. reset: everything must go to 0");
        RSTn = 0;
        #1;
        check(y_out == 0 && BUSY == 0 && DONE == 0 && SREADY == 0, "outputs not 0 after reset");
        for (int i = 0; i < 16; i++)
            check(dut.h[i] == 0 && dut.s[i] == 0, $sformatf("h[%0d] or s[%0d] not 0 after reset", i, i));
        for (int i = 0; i < 15; i++)
            check(dut.r[i] == 0, $sformatf("r[%0d] not 0 after reset", i));
        check(dut.CREQ == 0, "CREQ not 0 after reset");
        check(dones == 2, "expected exactly 2 commits in the whole test");

        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED (%0d errors)", errors);
        $finish;
    end

endmodule
