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
    logic signed [7:0] h0,h1,h2,h3,h4,h5,h6,h7,h8,h9,h10,h11,h12,h13,h14,h15;  // h = active impulse response (what the filter uses)
    logic signed [7:0] s0,s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14,s15;  // s = shadow impulse response (what the CPU writes)
    logic signed [15:0] r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14;  // r = accumulator path
logic CREQ;      // a commit was requested, stays 1 until it is served
logic SRSTATUS;  // 1 when all 16 shadow impulse response values have been written
always_comb SRSTATUS=&SREADY;
always_ff @(posedge CLK or negedge RSTn) begin
    if(!RSTn) begin
        h0<=8'sd0;
        h1<=8'sd0;
        h2<=8'sd0;
        h3<=8'sd0;
        h4<=8'sd0;
        h5<=8'sd0;
        h6<=8'sd0;
        h7<=8'sd0;
        h8<=8'sd0;
        h9<=8'sd0;
        h10<=8'sd0;
        h11<=8'sd0;
        h12<=8'sd0;
        h13<=8'sd0;
        h14<=8'sd0;
        h15<=8'sd0;
        s0<='0;
        s1<='0;
        s2<='0;
        s3<='0;
        s4<='0;
        s5<='0;
        s6<='0;
        s7<='0;
        s8<='0;
        s9<='0;
        s10<='0;
        s11<='0;
        s12<='0;
        s13<='0;
        s14<='0;
        s15<='0;
        SREADY<='0;
        CREQ<=1'b0;
        DONE<=1'b0;
        r0<='0;
        r1<='0;
        r2<='0;
        r3<='0;
        r4<='0;
        r5<='0;
        r6<='0;
        r7<='0;
        r8<='0;
        r9<='0;
        r10<='0;
        r11<='0;
        r12<='0;
        r13<='0;
        r14<='0;
        y_out<='0;
        BUSY<=1'b0;
    end
    else if(FIREN) begin
        DONE<=CREQ&&SRSTATUS;
        if(CREQ&&SRSTATUS) begin
            h0<=s0;
            h1<=s1;
            h2<=s2;
            h3<=s3;
            h4<=s4;
            h5<=s5;
            h6<=s6;
            h7<=s7;
            h8<=s8;
            h9<=s9;
            h10<=s10;
            h11<=s11;
            h12<=s12;
            h13<=s13;
            h14<=s14;
            h15<=s15;
            SREADY<='0;
            CREQ<=1'b0;
            r0<='0;
            r1<='0;
            r2<='0;
            r3<='0;
            r4<='0;
            r5<='0;
            r6<='0;
            r7<='0;
            r8<='0;
            r9<='0;
            r10<='0;
            r11<='0;
            r12<='0;
            r13<='0;
            r14<='0;
            y_out<='0;
            BUSY<=1'b0;
        end
        else begin
            y_out<=(x_in*h0)+r0;
            r0<=(x_in*h1)+r1;
            r1<=(x_in*h2)+r2;
            r2<=(x_in*h3)+r3;
            r3<=(x_in*h4)+r4;
            r4<=(x_in*h5)+r5;
            r5<=(x_in*h6)+r6;
            r6<=(x_in*h7)+r7;
            r7<=(x_in*h8)+r8;
            r8<=(x_in*h9)+r9;
            r9<=(x_in*h10)+r10;
            r10<=(x_in*h11)+r11;
            r11<=(x_in*h12)+r12;
            r12<=(x_in*h13)+r13;
            r13<=(x_in*h14)+r14;
            r14<=x_in*h15;
            BUSY<=1'b1;
        end
        if(COMMIT) CREQ<=1'b1;
        if(CENWR) begin
            case(CADDR)
                4'd0:  begin s0<=CDATA; SREADY[0]<=1'b1; end
                4'd1:  begin s1<=CDATA; SREADY[1]<=1'b1; end
                4'd2:  begin s2<=CDATA; SREADY[2]<=1'b1; end
                4'd3:  begin s3<=CDATA; SREADY[3]<=1'b1; end
                4'd4:  begin s4<=CDATA; SREADY[4]<=1'b1; end
                4'd5:  begin s5<=CDATA; SREADY[5]<=1'b1; end
                4'd6:  begin s6<=CDATA; SREADY[6]<=1'b1; end
                4'd7:  begin s7<=CDATA; SREADY[7]<=1'b1; end
                4'd8:  begin s8<=CDATA; SREADY[8]<=1'b1; end
                4'd9:  begin s9<=CDATA; SREADY[9]<=1'b1; end
                4'd10: begin s10<=CDATA; SREADY[10]<=1'b1; end
                4'd11: begin s11<=CDATA; SREADY[11]<=1'b1; end
                4'd12: begin s12<=CDATA; SREADY[12]<=1'b1; end
                4'd13: begin s13<=CDATA; SREADY[13]<=1'b1; end
                4'd14: begin s14<=CDATA; SREADY[14]<=1'b1; end
                4'd15: begin s15<=CDATA; SREADY[15]<=1'b1; end
            endcase
        end
    end
    else begin
        BUSY<=1'b0;
        DONE<=1'b0;
    end
end
endmodule
