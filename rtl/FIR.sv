(*use_dsp="yes"*)
module FIR(
    input logic CLK,                    // clock
    input logic RSTn,                   // active low asynchronous reset 
    input logic FIREN,                  // FIREN = filter enable; only reset still works. The CPU pulls it low when it detects an error
    input logic signed [3:0] x_in,      // input sample
    output logic signed [15:0] y_out,   // filter output, 16-bit signed
    output logic BUSY,                  // 1 while the filter is producing output
    input logic CENWR,                  // CENWR = coefficient enable write: write CDATA into the shadow registers at position CADDR
    input logic [3:0] CADDR,            // CADDR = coefficient address: which position (tap) of the impulse response to write, 0 to 15
    input logic signed [7:0] CDATA,     // CDATA = coefficient data: the impulse response value to store, 8-bit signed
    output logic [15:0] SREADY,         // SREADY = shadow ready: bit n is 1 once position n of the shadow impulse response has been written, commit clears them all
    input logic COMMIT,                 // CPU request to switch to the new impulse response. Send it as a 1-clock pulse while FIREN is high. It can come before all the writes are done, the FIR just waits for them
    output logic DONE                   // 1-clock pulse: the new impulse response is now active. If the CPU does not see it in time, it treats that as an error and pulls FIREN low
);
    // h, s and r are unpacked arrays on purpose: h[i], s[i] and r[i] stay signed (in a packed array the SV standard makes them unsigned)
    logic signed [7:0] h [0:15];  // h = active impulse response (what the filter uses)
    logic signed [7:0] s [0:15];  // s = shadow impulse response (what the CPU writes)
    logic signed [15:0] r [0:14];  // r = accumulator path
logic CREQ;      // a commit was requested, stays 1 until it is served
logic SRSTATUS;  // 1 when all 16 shadow impulse response values have been written
always_comb SRSTATUS=&SREADY;
always_ff @(posedge CLK or negedge RSTn) begin
    if(!RSTn) begin
        for(int i=0;i<16;i++) h[i]<=8'sd0;
        for(int i=0;i<16;i++) s[i]<='0;
        SREADY<='0;
        CREQ<=1'b0;
        DONE<=1'b0;
        for(int i=0;i<15;i++) r[i]<='0;
        y_out<='0;
        BUSY<=1'b0;
    end
    else if(FIREN) begin
        DONE<=CREQ&&SRSTATUS;
        if(CREQ&&SRSTATUS) begin
            for(int i=0;i<16;i++) h[i]<=s[i];
            SREADY<='0;
            CREQ<=1'b0;
            for(int i=0;i<15;i++) r[i]<='0;
            y_out<='0;
            BUSY<=1'b0;
        end
        else begin
            y_out<=(x_in*h[0])+r[0];
            for(int i=0;i<14;i++) r[i]<=(x_in*h[i+1])+r[i+1];
            r[14]<=x_in*h[15];
            BUSY<=1'b1;
        end
        if(COMMIT) CREQ<=1'b1;
        if(CENWR) begin
            case(CADDR)
                4'd0:  begin s[0]<=CDATA; SREADY[0]<=1'b1; end
                4'd1:  begin s[1]<=CDATA; SREADY[1]<=1'b1; end
                4'd2:  begin s[2]<=CDATA; SREADY[2]<=1'b1; end
                4'd3:  begin s[3]<=CDATA; SREADY[3]<=1'b1; end
                4'd4:  begin s[4]<=CDATA; SREADY[4]<=1'b1; end
                4'd5:  begin s[5]<=CDATA; SREADY[5]<=1'b1; end
                4'd6:  begin s[6]<=CDATA; SREADY[6]<=1'b1; end
                4'd7:  begin s[7]<=CDATA; SREADY[7]<=1'b1; end
                4'd8:  begin s[8]<=CDATA; SREADY[8]<=1'b1; end
                4'd9:  begin s[9]<=CDATA; SREADY[9]<=1'b1; end
                4'd10: begin s[10]<=CDATA; SREADY[10]<=1'b1; end
                4'd11: begin s[11]<=CDATA; SREADY[11]<=1'b1; end
                4'd12: begin s[12]<=CDATA; SREADY[12]<=1'b1; end
                4'd13: begin s[13]<=CDATA; SREADY[13]<=1'b1; end
                4'd14: begin s[14]<=CDATA; SREADY[14]<=1'b1; end
                4'd15: begin s[15]<=CDATA; SREADY[15]<=1'b1; end
            endcase
        end
    end
    else begin
        BUSY<=1'b0;
        DONE<=1'b0;
    end
end
endmodule
