(*use_dsp="yes"*)

module FIR(
    input logic clk,
    input logic rst,
    input logic signed [3:0] x_in,
    output logic signed [11:0] y_out
);
logic clk_in;
  clk_wiz_0 instance_name
   (.clk_out1(clk_in),.reset(rst),.clk_in1(clk));
localparam signed [7:0] h0=8'sd0;
localparam signed [7:0] h1=8'sd41;
localparam signed [7:0] h2=8'sd64;
localparam signed [7:0] h3=8'sd41;
localparam signed [7:0] h4=8'sd0;
logic signed [7:0] r0,r1,r2,r3;
always @(posedge clk_in or posedge rst) begin
    if(rst) begin
        r0<='0;
        r1<='0;
        r2<='0;
        r3<='0;
        y_out<='0;
    end
    else begin
        y_out<=(x_in*h0)+r0;
        r0<=(x_in*h1)+r1;
        r1<=(x_in*h2)+r2;
        r2<=(x_in*h3)+r3;
        r3<=x_in*h4;
    end
end
endmodule
