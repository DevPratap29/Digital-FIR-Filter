
/*
1. Assert RSTn, then remove reset.

2. Load the impulse response coefficients for a bandpass filter with
   cutoff frequencies pi/4 and 3*pi/4. Write the coefficients in random
   address order rather than sequential order. Send COMMIT in the middle
   of the coefficient writes, before all coefficients have been loaded.

3. Let the filter run for some time so its response can be observed.

4. Deassert FIREN to check whether the filter halts its operation.

5. Assert FIREN again to resume normal operation.

6. While the filter is operating normally, load new impulse response
   coefficients for a high-pass filter with cutoff frequency 2*pi/3.
   Write the coefficients in random address order and send COMMIT before
   all coefficients have been loaded.

7. Let the filter run for some time to observe its response with the
   new high-pass filter coefficients.

8. Deassert FIREN, then assert RSTn.

9. Do not implement self-checking or automatic pass/fail logic. All
   correctness checks will be performed manually by observing waveforms
   and console output.

10. Display all signal values on every rising clock edge in the Tcl
    console. Do not print on falling clock edges.

11. Display all active coefficient registers h[0:15], all shadow
    coefficient registers s[0:15], and all datapath registers r[0:14],
    along with the external signals and internal control signals.
*/

`timescale 1ns / 1ps

module FIR_tb;

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

    FIR dut (
        .CLK(CLK),
        .RSTn(RSTn),
        .FIREN(FIREN),
        .x_in(x_in),
        .y_out(y_out),
        .BUSY(BUSY),
        .CENWR(CENWR),
        .CADDR(CADDR),
        .CDATA(CDATA),
        .SREADY(SREADY),
        .COMMIT(COMMIT),
        .DONE(DONE)
    );

    initial CLK = 0;
    always #5 CLK = ~CLK;

    logic signed [15:0] bp_coeff [0:15];
    logic signed [15:0] hp_coeff [0:15];

    initial begin
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

    integer sample_index;
    real pi;
    real sample_value;

    initial begin
        sample_index = 0;
        pi = 3.141592653589793;
    end

    always @(negedge CLK) begin
        if (RSTn && FIREN) begin
            sample_value =
                  500.0 * $sin(pi * sample_index / 8.0)
                + 700.0 * $sin(pi * sample_index / 2.0)
                + 500.0 * $sin(5.0 * pi * sample_index / 6.0);

            x_in <= $rtoi(sample_value);
            sample_index <= sample_index + 1;
        end
    end

    initial begin
        $display("TIME CLK RSTn FIREN x_in CENWR CADDR CDATA COMMIT BUSY DONE SREADY CREQ SRSTATUS SWAP y_out");
    end

    always @(posedge CLK) begin
        #1;
        $display("%0t  %b   %b    %b    %0d   %b     %0d     %08h  %b      %b    %b   %04h  %b    %b       %b   %0d",
            $time, CLK, RSTn, FIREN, $signed(x_in),
            CENWR, CADDR, CDATA, COMMIT, BUSY, DONE, SREADY,
            dut.CREQ, dut.SRSTATUS, dut.SWAP, $signed(y_out)
        );
    end

    initial begin
        RSTn = 0;
        FIREN = 0;
        x_in = 0;
        CENWR = 0;
        CADDR = 0;
        CDATA = 0;
        COMMIT = 0;

        #40;
        RSTn = 1;
        FIREN = 1;

        #30;

        CENWR = 1;
        CADDR = 4'd7;
        CDATA = bp_coeff[7];
        #10;
        CADDR = 4'd2;
        CDATA = bp_coeff[2];
        #10;
        CADDR = 4'd13;
        CDATA = bp_coeff[13];
        #10;
        CADDR = 4'd0;
        CDATA = bp_coeff[0];
        #10;
        CADDR = 4'd9;
        CDATA = bp_coeff[9];
        #10;
        CADDR = 4'd4;
        CDATA = bp_coeff[4];
        #10;
        CADDR = 4'd15;
        CDATA = bp_coeff[15];

        #10;
        CENWR = 0;
        COMMIT = 1;
        #10;
        COMMIT = 0;

        CENWR = 1;
        CADDR = 4'd1;
        CDATA = bp_coeff[1];
        #10;
        CADDR = 4'd11;
        CDATA = bp_coeff[11];
        #10;
        CADDR = 4'd6;
        CDATA = bp_coeff[6];
        #10;
        CADDR = 4'd3;
        CDATA = bp_coeff[3];
        #10;
        CADDR = 4'd14;
        CDATA = bp_coeff[14];
        #10;
        CADDR = 4'd8;
        CDATA = bp_coeff[8];
        #10;
        CADDR = 4'd5;
        CDATA = bp_coeff[5];
        #10;
        CADDR = 4'd12;
        CDATA = bp_coeff[12];
        #10;
        CADDR = 4'd10;
        CDATA = bp_coeff[10];
        #10;
        CENWR = 0;
        CDATA = 0;

        #400;

        FIREN = 0;
        #80;
        FIREN = 1;

        #200;

        CENWR = 1;
        CADDR = 4'd10;
        CDATA = hp_coeff[10];
        #10;
        CADDR = 4'd3;
        CDATA = hp_coeff[3];
        #10;
        CADDR = 4'd14;
        CDATA = hp_coeff[14];
        #10;
        CADDR = 4'd1;
        CDATA = hp_coeff[1];
        #10;
        CADDR = 4'd8;
        CDATA = hp_coeff[8];
        #10;
        CADDR = 4'd5;
        CDATA = hp_coeff[5];
        #10;
        CADDR = 4'd12;
        CDATA = hp_coeff[12];

        #10;
        CENWR = 0;
        COMMIT = 1;
        #10;
        COMMIT = 0;

        CENWR = 1;
        CADDR = 4'd0;
        CDATA = hp_coeff[0];
        #10;
        CADDR = 4'd15;
        CDATA = hp_coeff[15];
        #10;
        CADDR = 4'd6;
        CDATA = hp_coeff[6];
        #10;
        CADDR = 4'd11;
        CDATA = hp_coeff[11];
        #10;
        CADDR = 4'd2;
        CDATA = hp_coeff[2];
        #10;
        CADDR = 4'd9;
        CDATA = hp_coeff[9];
        #10;
        CADDR = 4'd4;
        CDATA = hp_coeff[4];
        #10;
        CADDR = 4'd13;
        CDATA = hp_coeff[13];
        #10;
        CADDR = 4'd7;
        CDATA = hp_coeff[7];
        #10;
        CENWR = 0;
        CDATA = 0;

        #600;

        FIREN = 0;
        #50;
        RSTn = 0;

        #30;
        $finish;
    end

endmodule
