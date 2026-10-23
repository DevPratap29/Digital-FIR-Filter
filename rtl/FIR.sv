(*use_dsp="yes"*)
module FIR(
    input logic CLK,                    // clock
    input logic RSTn,                   // active low reset, has priority over FIREN. Control registers reset asynchronously, the filter math (r, y_out) resets on the next clock edge
    input logic FIREN,                  // FIREN = filter enable; only reset still works. The CPU pulls it low when it detects an error
    input logic signed [11:0] x_in,     // input sample, 12-bit signed
    output logic signed [31:0] y_out,   // filter output, 32-bit signed. Full precision: 12 + 16 + 4 = 32 bits, so it can never overflow
    output logic BUSY,                  // 1 while the filter is producing output
    input logic CENWR,                  // CENWR = coefficient enable write: write CDATA into the shadow registers at position CADDR
    input logic [3:0] CADDR,            // CADDR = coefficient address: which position (tap) of the impulse response to write, 0 to 15
    input logic [31:0] CDATA,           // CDATA = coefficient data, one 32-bit bus word: bits [15:0] hold the 16-bit signed value, bits [31:16] are ignored. The CPU must write values from -32768 to 32767
    output logic [15:0] SREADY,         // SREADY = shadow ready: bit n is 1 once position n of the shadow impulse response has been written, commit clears them all
    input logic COMMIT,                 // CPU request to switch to the new impulse response. Send it as a 1-clock pulse while FIREN is high. It can come before all the writes are done, the FIR just waits for them
    output logic DONE                   // 1-clock pulse: the new impulse response is now active. If the CPU does not see it in time, it treats that as an error and pulls FIREN low
);
    // h, s and r are unpacked arrays on purpose: h[i], s[i] and r[i] stay signed (in a packed array the SV standard makes them unsigned)
    logic signed [15:0] h [0:15];  // h = active impulse response (what the filter uses), 16-bit signed
    logic signed [15:0] s [0:15];  // s = shadow impulse response (what the CPU writes), 16-bit signed
    logic signed [31:0] r [0:14];  // r = accumulator path, 32-bit signed (full precision)
logic CREQ;      // a commit was requested, stays 1 until it is served
logic SRSTATUS;  // 1 when all 16 shadow impulse response values have been written
logic SWAP;      // 1 in the clock where the shadow impulse response is copied into the active one
always_comb SRSTATUS=&SREADY;
always_comb SWAP=CREQ&&SRSTATUS;

// Control and coefficients: asynchronous reset, same as before
always_ff @(posedge CLK or negedge RSTn) begin
    if(!RSTn) begin
        for(int i=0;i<16;i++) h[i]<='0;
        for(int i=0;i<16;i++) s[i]<='0;
        SREADY<='0;
        CREQ<=1'b0;
        DONE<=1'b0;
        BUSY<=1'b0;
    end
    else if(FIREN) begin
        DONE<=SWAP;
        if(SWAP) begin
            for(int i=0;i<16;i++) h[i]<=s[i];
            SREADY<='0;
            CREQ<=1'b0;
            BUSY<=1'b0;
        end
        else begin
            BUSY<=1'b1;
        end
        if(COMMIT) CREQ<=1'b1;
        if(CENWR) begin
            s[CADDR]<=CDATA[15:0];    // keep only the 16 real bits; s is signed, so the value stays signed
            SREADY[CADDR]<=1'b1;
        end
    end
    else begin
        BUSY<=1'b0;
        DONE<=1'b0;
    end
end

// Filter math: synchronous reset, so r and y_out can be packed inside the DSP slices
always_ff @(posedge CLK) begin
    if(!RSTn) begin
        for(int i=0;i<15;i++) r[i]<='0;
        y_out<='0;
    end
    else if(FIREN) begin
        if(SWAP) begin
            for(int i=0;i<15;i++) r[i]<='0;
            y_out<='0;
        end
        else begin
            y_out<=(x_in*h[0])+r[0];
            for(int i=0;i<14;i++) r[i]<=(x_in*h[i+1])+r[i+1];
            r[14]<=x_in*h[15];
        end
    end
end
endmodule
