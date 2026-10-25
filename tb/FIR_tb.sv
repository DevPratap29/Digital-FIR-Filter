
`timescale 1ns / 1ps

module FIR_tb;

    // =========================================================
    // DUT INPUTS AND OUTPUTS -- MATCHING EXACT PORT WIDTHS
    // =========================================================
    logic CLK;
    logic RSTn;
    logic FIREN;

    logic signed [11:0] x_in;
    logic signed [31:0] y_out;

    logic BUSY;
    logic CENWR;
    logic [3:0] CADDR;
    logic [31:0] CDATA;
    logic [15:0] SREADY;
    logic COMMIT;
    logic DONE;

    // =========================================================
    // DUT INSTANTIATION
    // =========================================================
    FIR dut (
        .CLK    (CLK),
        .RSTn   (RSTn),
        .FIREN  (FIREN),
        .x_in   (x_in),
        .y_out  (y_out),
        .BUSY   (BUSY),
        .CENWR  (CENWR),
        .CADDR  (CADDR),
        .CDATA  (CDATA),
        .SREADY (SREADY),
        .COMMIT (COMMIT),
        .DONE   (DONE)
    );

    // =========================================================
    // CLOCK: 100 MHz
    // =========================================================
    initial CLK = 1'b0;
    always #5 CLK = ~CLK;

    // =========================================================
    // COEFFICIENTS: SIGNED Q1.15 FIXED-POINT
    //
    // Bandpass: cutoff frequencies pi/4 and 3*pi/4
    // Highpass: cutoff frequency 2*pi/3
    //
    // Coefficients are calculated using windowed-sinc FIR
    // design, then quantized to signed 16-bit integers.
    // =========================================================
    logic signed [15:0] bp_coeff [0:15];
    logic signed [15:0] hp_coeff [0:15];

    integer i;

    initial begin
        // 16-tap bandpass, Hamming window
        bp_coeff[ 0] = -16'sd60;
        bp_coeff[ 1] =  16'sd251;
        bp_coeff[ 2] =  16'sd574;
        bp_coeff[ 3] = -16'sd498;
        bp_coeff[ 4] =  16'sd946;
        bp_coeff[ 5] = -16'sd4188;
        bp_coeff[ 6] = -16'sd8268;
        bp_coeff[ 7] =  16'sd11151;
        bp_coeff[ 8] =  16'sd11151;
        bp_coeff[ 9] = -16'sd8268;
        bp_coeff[10] = -16'sd4188;
        bp_coeff[11] =  16'sd946;
        bp_coeff[12] = -16'sd498;
        bp_coeff[13] =  16'sd574;
        bp_coeff[14] =  16'sd251;
        bp_coeff[15] = -16'sd60;

        // 15-tap highpass, Hamming window, cutoff 2*pi/3.
        // The 16th hardware coefficient is zero.
        // This preserves an odd-length, symmetric highpass
        // design while still writing all 16 hardware slots.
        hp_coeff[ 0] = -16'sd103;
        hp_coeff[ 1] =  16'sd0;
        hp_coeff[ 2] =  16'sd455;
        hp_coeff[ 3] = -16'sd983;
        hp_coeff[ 4] =  16'sd0;
        hp_coeff[ 5] =  16'sd3714;
        hp_coeff[ 6] = -16'sd8574;
        hp_coeff[ 7] =  16'sd10863;
        hp_coeff[ 8] = -16'sd8574;
        hp_coeff[ 9] =  16'sd3714;
        hp_coeff[10] =  16'sd0;
        hp_coeff[11] = -16'sd983;
        hp_coeff[12] =  16'sd455;
        hp_coeff[13] =  16'sd0;
        hp_coeff[14] = -16'sd103;
        hp_coeff[15] =  16'sd0;
    end

    // =========================================================
    // DETERMINISTIC INPUT SIGNAL
    //
    // x[n] = 500 sin(pi*n/8)
    //      + 700 sin(pi*n/2)
    //      + 500 sin(5*pi*n/6)
    //
    // Components:
    // pi/8   : below bandpass passband
    // pi/2   : inside bandpass passband
    // 5*pi/6 : above bandpass passband and above highpass cutoff
    //
    // The resulting samples fit within signed 12-bit range.
    // =========================================================
    integer sample_index;

    function automatic logic signed [11:0]
        sample_for(input integer n);

        real pi;
        real value;

        begin
            pi = 3.141592653589793;

            value =
                  500.0 * $sin(pi * n / 8.0)
                + 700.0 * $sin(pi * n / 2.0)
                + 500.0 * $sin(5.0 * pi * n / 6.0);

            sample_for = $rtoi(value);
        end
    endfunction

    // Drive a new sample on each falling edge while enabled.
    // The DUT consumes that sample on the following rising edge.
    initial sample_index = 0;

    always @(negedge CLK) begin
        if (RSTn && FIREN) begin
            x_in <= sample_for(sample_index);
            sample_index <= sample_index + 1;
        end
    end

    // =========================================================
    // COEFFICIENT WRITE TASK
    //
    // CDATA[15:0] = signed coefficient.
    // CDATA[31:16] = zero, as required by the DUT.
    // One write per rising clock edge.
    // =========================================================
    task automatic write_coeff(
        input logic [3:0] addr,
        input logic signed [15:0] coeff
    );
        begin
            @(negedge CLK);
            CENWR = 1'b1;
            CADDR = addr;
            CDATA = {16'h0000, coeff};

            @(negedge CLK);
            CENWR = 1'b0;
            CDATA = 32'h00000000;
        end
    endtask

    // =========================================================
    // COMMIT TASK
    // One-clock pulse.
    // =========================================================
    task automatic send_commit;
        begin
            @(negedge CLK);
            COMMIT = 1'b1;

            @(negedge CLK);
            COMMIT = 1'b0;
        end
    endtask

    // =========================================================
    // WAIT TASK
    // =========================================================
    task automatic wait_cycles(input integer count);
        repeat (count) @(posedge CLK);
    endtask

    // =========================================================
    // CONSOLE MONITOR
    //
    // Print once per rising edge, AFTER nonblocking assignments
    // have settled. Includes all external signals and all
    // active, shadow and datapath registers.
    //
    // This is observation only: no checking or pass/fail logic.
    // =========================================================
    always @(posedge CLK) begin
        #1;

        $display("");
        $display("============================================================");
        $display("TIME=%0t ns | CLK=%0b | RSTn=%0b | FIREN=%0b",
                 $time, CLK, RSTn, FIREN);
        $display("============================================================");

        $display("INPUTS:");
        $display("x_in=%0d  CENWR=%0b  CADDR=%0d  CDATA=0x%08h  COMMIT=%0b",
                 $signed(x_in), CENWR, CADDR, CDATA, COMMIT);

        $display("STATUS:");
        $display("BUSY=%0b  DONE=%0b  SREADY=0x%04h",
                 BUSY, DONE, SREADY);

        $display("INTERNAL CONTROL:");
        $display("CREQ=%0b  SRSTATUS=%0b  SWAP=%0b",
                 dut.CREQ, dut.SRSTATUS, dut.SWAP);

        $display("ACTIVE COEFFICIENTS h[0:15]:");
        for (integer j = 0; j < 16; j = j + 1)
            $display("h[%0d] = %0d", j, $signed(dut.h[j]));

        $display("SHADOW COEFFICIENTS s[0:15]:");
        for (integer j = 0; j < 16; j = j + 1)
            $display("s[%0d] = %0d", j, $signed(dut.s[j]));

        $display("DATAPATH REGISTERS r[0:14]:");
        for (integer j = 0; j < 15; j = j + 1)
            $display("r[%0d] = %0d", j, $signed(dut.r[j]));

        $display("OUTPUT:");
        $display("y_out = %0d", $signed(y_out));

        $display("============================================================");
    end

    // =========================================================
    // MAIN TEST SEQUENCE
    // =========================================================
    initial begin

        // -----------------------------------------------------
        // INITIALIZE ALL DRIVEN CONTROL SIGNALS
        // -----------------------------------------------------
        RSTn   = 1'b0;
        FIREN  = 1'b0;
        x_in   = 12'sd0;
        CENWR  = 1'b0;
        CADDR  = 4'd0;
        CDATA  = 32'd0;
        COMMIT = 1'b0;

        // -----------------------------------------------------
        // PHASE 1: RESET, THEN RELEASE
        // -----------------------------------------------------
        wait_cycles(4);

        @(negedge CLK);
        RSTn  = 1'b1;
        FIREN = 1'b1;

        wait_cycles(3);

        // -----------------------------------------------------
        // PHASE 2: LOAD BANDPASS COEFFICIENTS IN SHUFFLED ORDER
        //
        // COMMIT is deliberately sent after seven writes.
        // The remaining writes happen while CREQ is pending.
        // -----------------------------------------------------
        write_coeff(4'd7,  bp_coeff[7]);
        write_coeff(4'd2,  bp_coeff[2]);
        write_coeff(4'd13, bp_coeff[13]);
        write_coeff(4'd0,  bp_coeff[0]);
        write_coeff(4'd9,  bp_coeff[9]);
        write_coeff(4'd4,  bp_coeff[4]);
        write_coeff(4'd15, bp_coeff[15]);

        // Early commit: only 7 of 16 coefficients are written.
        send_commit();

        write_coeff(4'd1,  bp_coeff[1]);
        write_coeff(4'd11, bp_coeff[11]);
        write_coeff(4'd6,  bp_coeff[6]);
        write_coeff(4'd3,  bp_coeff[3]);
        write_coeff(4'd14, bp_coeff[14]);
        write_coeff(4'd8,  bp_coeff[8]);
        write_coeff(4'd5,  bp_coeff[5]);
        write_coeff(4'd12, bp_coeff[12]);
        write_coeff(4'd10, bp_coeff[10]);

        // Allow the pending commit and filter operation to proceed.
        wait_cycles(40);

        // -----------------------------------------------------
        // PHASE 3: HALT USING FIREN
        // -----------------------------------------------------
        @(negedge CLK);
        FIREN = 1'b0;

        wait_cycles(8);

        // -----------------------------------------------------
        // PHASE 4: RESUME FILTER OPERATION
        // -----------------------------------------------------
        @(negedge CLK);
        FIREN = 1'b1;

        wait_cycles(20);

        // -----------------------------------------------------
        // PHASE 5: LOAD HIGHPASS WHILE FILTER IS RUNNING
        //
        // Active bandpass coefficients remain in h[] until
        // the new complete set is committed.
        // -----------------------------------------------------
        write_coeff(4'd10, hp_coeff[10]);
        write_coeff(4'd3,  hp_coeff[3]);
        write_coeff(4'd14, hp_coeff[14]);
        write_coeff(4'd1,  hp_coeff[1]);
        write_coeff(4'd8,  hp_coeff[8]);
        write_coeff(4'd5,  hp_coeff[5]);
        write_coeff(4'd12, hp_coeff[12]);

        // Early commit while the filter continues running.
        send_commit();

        write_coeff(4'd0,  hp_coeff[0]);
        write_coeff(4'd15, hp_coeff[15]);
        write_coeff(4'd6,  hp_coeff[6]);
        write_coeff(4'd11, hp_coeff[11]);
        write_coeff(4'd2,  hp_coeff[2]);
        write_coeff(4'd9,  hp_coeff[9]);
        write_coeff(4'd4,  hp_coeff[4]);
        write_coeff(4'd13, hp_coeff[13]);
        write_coeff(4'd7,  hp_coeff[7]);

        // -----------------------------------------------------
        // PHASE 6: OBSERVE HIGHPASS OPERATION
        // -----------------------------------------------------
        wait_cycles(60);

        // -----------------------------------------------------
        // PHASE 7: HALT, THEN ASSERT RESET AGAIN
        // -----------------------------------------------------
        @(negedge CLK);
        FIREN = 1'b0;

        wait_cycles(5);

        @(negedge CLK);
        RSTn = 1'b0;

        // Synchronous datapath reset is observed on clock edge.
        wait_cycles(3);

        $finish;
    end

endmodule
