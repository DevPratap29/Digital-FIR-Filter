module fir(
input logic clk,
input logic rst,
input logic signed [15:0] x_in,
output logic signed [15:0] y_out
);
logic signed [15:0] h [0:15];
logic signed [15:0] x [0:15];
logic signed [15:0] s0,s1,s2,s3,s4,s5,s6,s7,s8;
logic signed [15:0] m0,m1,m2,m3,m4,m5,m6,m7,m8;
integer i;
always_ff @(posedge clk or posedge rst) begin
    if(rst) begin
        h[0]<=16'sd0;
        h[1]<=-16'sd6;
        h[2]<=16'sd0;
        h[3]<=16'sd8;
        h[4]<=16'sd0;
        h[5]<=-16'sd14;
        h[6]<=16'sd0;
        h[7]<=16'sd41;
        h[8]<=16'sd64;
    end
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
s0<=x_in+x[15];
s1<=x[0]+x[14];
s2<=x[1]+x[13];
s3<=x[2]+x[12];
s4<=x[3]+x[11];
s5<=x[4]+x[10];
s6<=x[5]+x[9];
s7<=x[6]+x[8];
s8<=x[7];
end
end
always_ff@(posedge clk or posedge rst)begin
if(rst)begin
m0<=0;m1<=0;m2<=0;m3<=0;m4<=0;m5<=0;m6<=0;m7<=0;m8<=0;
end
else begin
m0<=s0*h[0];
m1<=s1*h[1];
m2<=s2*h[2];
m3<=s3*h[3];
m4<=s4*h[4];
m5<=s5*h[5];
m6<=s6*h[6];
m7<=s7*h[7];
m8<=s8*h[8];
end
end
always_ff@(posedge clk or posedge rst)begin
if(rst)begin
y_out<='0;
end
else begin
y_out<=m0+m1+m2+m3+m4+m5+m6+m7+m8;
end
end
endmodule



module fir_tb;
logic clk;
logic rst;
logic signed [15:0] x_in;
logic signed [15:0] y_out;
fir dut (.clk(clk),.rst(rst),.x_in(x_in),.y_out(y_out));
always #5 clk = ~clk;
initial begin
clk = 0;
rst = 1;
x_in = '0;
#20;
rst = 0;
repeat (15) begin
#10 x_in = x_in + 8'sd1;
end
#160;
rst=1;
#180;
$finish;
end
initial begin
$display("Time\tclk\tx_in\ty_out");
$monitor("%0t\t%b\t%d\t%d", $time, clk, x_in, y_out);
end
endmodule

