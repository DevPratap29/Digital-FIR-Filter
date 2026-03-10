module fir(
input logic clk,
input logic rst,
input logic signed [15:0] x_in,
output logic signed [15:0] y_out
);
logic signed [15:0] h [0:15];
logic signed [15:0] x [0:15];
logic signed [15:0] s1,s2,s3,s4,s5,s6,s7,s8;
logic signed [15:0] m1,m2,m3,m4,m5,m6,m7,m8;
integer i;
initial begin
h[0] = -8'sd3;
h[1] = -8'sd1;
h[2] = 8'sd3;
h[3] = 8'sd7;
h[4] = 8'sd11;
h[5] = 8'sd15;
h[6] = 8'sd19;
h[7] = 8'sd20;
end
always_ff@(posedge clk or posedge rst) begin
if(rst)begin
for(i=0;i<16;i++)begin
 x[i]<='0;
end
end
else begin
for(i=15;i>0;i--)begin
 x[i]<=x[i-1];
end
x[0]<=x_in;
s1<=x[0]+x[15];
s2<=x[1]+x[14];
s3<=x[2]+x[13];
s4<=x[3]+x[12];
s5<=x[4]+x[11];
s6<=x[5]+x[10];
s7<=x[6]+x[9];
s8<=x[7]+x[8];
end
end
always_ff@(posedge clk or posedge rst)begin
if(rst)begin
m1<=0;m2<=0;m3<=0;m4<=0;m5<=0;m6<=0;m7<=0;m8<=0;
end
else begin
m1<=s1*h[0];
m2<=s2*h[1];
m3<=s3*h[2];
m4<=s4*h[3];
m5<=s5*h[4];
m6<=s6*h[5];
m7<=s7*h[6];
m8<=s8*h[7];
end
end
always_ff@(posedge clk or posedge rst)begin
if(rst)begin
y_out<='0;
end
else begin
y_out<=m1+m2+m3+m4+m5+m6+m7+m8;
end
end
endmodule



module fir_tb;
logic clk;
logic reset;
logic signed [15:0] x_in;
logic signed [15:0] y_out;
fir dut (.clk(clk),.rst(rst),.x_in(x_in),.y_out(y_out));
always #5 clk = ~clk;
initial begin
clk = 0;
reset = 1;
x_in = '0;
#20;
reset = 0;
repeat (15) begin
#10 x_in = x_in + 8'sd1;
end
#160;
$finish;
end
initial begin
$display("Time\tclk\tx_in\ty_out");
$monitor("%0t\t%b\t%d\t%d", $time, clk, x_in, y_out);
end
endmodule

