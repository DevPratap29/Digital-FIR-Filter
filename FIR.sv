module FIR(
    input logic clk,
    input logic rst,
    input logic signed [3:0] x_in,
    output logic signed [7:0] y_out
);

localparam signed [3:0] h0=4'sd1;
localparam signed [3:0] h1=4'sd2;
localparam signed [3:0] h2=4'sd3;
localparam signed [3:0] h3=4'sd4;
localparam signed [3:0] h4=4'sd5;
logic signed [7:0] r0,r1,r2,r3;
logic clk_5mhz;  //1hz clk
logic locked;   //1hz clk
logic clk_1hz;  //1hz clk
logic [22:0] count;  //1hz clk
clk_wiz_0 clk_gen(.clk_in1(clk),.reset(rst),.clk_out1(clk_5mhz),.locked(locked));  //1hz clk
always_ff @(posedge clk_5mhz or posedge rst) begin  //1hz clk
    if(rst) begin  //1hz clk
        count<=0;  //1hz clk
        clk_1hz<=0;  //1hz clk
    end  //1hz clk
    else begin  //1hz clk
        if(count==2499999) begin  //1hz clk
            count<=0;  //1hz clk
            clk_1hz<=~clk_1hz;  //1hz clk
        end  //1hz clk
        else begin  //1hz clk
            count<=count+1;  //1hz clk
        end  //1hz clk
    end  //1hz clk
end  //1hz clk
always_ff @(posedge clk_1hz or posedge rst) begin
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