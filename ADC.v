
module ADC2 (
    input  wire        clk,
    input  wire        enable,
    input  wire        spi_miso, // ADC output and inpput to master
    output wire        clk_out,
    output wire        a1,
    output wire        a2,
    output reg         spi_sck, // SPI clock 
    output reg         amp_cs,
    output reg         adc_conv, // ADC controller conversion signal
    output reg         spi_mosi,
    output reg         amp_shdn,
    output wire        spi_ss_b, sf_ce0, fpga_init_b, dac_cs, // disabling signal
    output reg  [13:0] adc_data1,
    output reg  [13:0] adc_data2, 
    output wire [33:0] adc_data // 2'bzz + 14 bit (ch A output) + 2'bzz 14 bit (ch B output) + 2'bzz 
);                              // 2 + 14 + 2 + 14 + 2 = 34 

reg adc_sent = 0;

reg [2:0] cnt = 0;
reg [3:0] clk_10_count = 0;
reg [6:0] adc_clk_count = 0; // For 34 clock pulse
reg [5:0] adc_bit_count = 14;    // count for 16 clock pulse (14 databit 2 high impedence state)
reg [3:0] gain_count = 8;   // gain count of 8 bit
reg [4:0] pos_count, neg_count;

reg [7:0] data_gain = 8'b00010001; // setting GAIN = -1 (INITIALIZATION)

reg [5:0] state = 6'b000000;

// Disabling other peripheral communicating with SPI BUS

assign spi_ss_b = 0;    // SPI Serial Flash
assign sf_ce0 = 1;  // StrataFlash Parallel Flash PROM
assign fpga_init_b = 1; // platform Flash PROM
assign dac_cs = 1;  // DAC (Digital to Analog Converter)

// clok division by 25 (Spartan-3E --> 50mhz) 
always @ (posedge clk or posedge enable) begin
    if (enable) begin
        pos_count <= 0;
    end 
    else begin
        if (pos_count == 24) pos_count <= 0;
        else pos_count <= pos_count + 1;
    end
end

always @ (negedge clk or posedge enable) begin
    if (enable) begin
        neg_count <= 0;
     end
     else begin
        if (neg_count == 24) neg_count <= 0;
        else neg_count <= neg_count + 1;
     end
end

assign clk_out = ((pos_count > (25 >> 1)) | (neg_count > (25 >> 1) ));
assign a1 = amp_cs;
assign a2 = adc_conv;

//The sampled analog value is converted to digital data 32 SPI_SCK cycles
//after asserting AD_CONV

 assign adc_data = {2'bzz, adc_data1, 2'bzz, adc_data2, 2'bzz};

always @ (posedge clk_out or posedge enable) begin
    if (enable) begin
        spi_sck <= 0;
        amp_shdn <= 0;
        adc_conv <= 0;
        amp_cs <= 1;
        spi_mosi <= 0;
        // ac_data1 <= 14'b10110010000111
        state <= 1;
        end
        
        else begin
        
        case (state) // states of ADC
        
        1: begin
            state <= 2;
        end
        2: begin
            spi_sck <= 0;
            amp_cs <= 0;
            state <= 3;
        end
        3: begin
            spi_sck <= 0;
            state <= 4;
        end
        4: begin    // Gain setting
            spi_sck <= 0;
            amp_shdn <= 0;
            amp_cs <= 0;
            spi_mosi <= data_gain [gain_count - 1];
            gain_count <= gain_count - 1;
            state <= 5;
        end
        5: begin
            amp_cs <= 0;
            spi_sck <= 1;
            if (gain_count > 0) state <= 6;
            else begin
                spi_sck <= 1;
                amp_shdn <= 0;
                amp_cs <= 0;
                gain_count <= 8;
                state <= 7;
            end
        end
        6: begin
            spi_sck <= 1;
            state <= 3;
        end
        7: begin
            amp_cs <= 0;
            spi_sck <= 1;
            state <= 8;
        end
        8: begin
            spi_sck <= 0;
            state <= 9;
        end
        9: begin
            spi_sck <= 0;
            state <= 10;
        end
        10: begin
            if (cnt > 5) begin // DELAY
                spi_sck <= 0;
                state <= 11;
                cnt <= 0;
            end
            else begin
                cnt <= cnt + 1;
                spi_sck <= 0;
            end
        end
        
        11: begin
            amp_cs <= 1; // Disabling gain setting after setting gain 
            spi_sck <= 0;
            state <= 12;
        end
        
        12: begin
            spi_sck <= 0;
            state <= 13;
        end
        
        13: begin
            spi_sck <= 1;
            state <= 14;
        end
        
        14: begin
            spi_sck <= 1;
            state <= 15;
        end
        
        15: begin
            spi_sck <= 0;
            state <= 30;
        end
        
        30: begin
            spi_sck <= 0;
            state <= 16;
        end
        
        16: begin
            adc_conv <= 1;  // Start ADCs from here
            spi_sck <= 0;
            state <= 17;
        end
        
        17: begin
            spi_sck <= 0;
            state <= 18;
        end
        
        18: begin
            adc_conv <= 0;
            spi_sck <= 0;
            state <= 19;
        end
        
        19: begin
            if (cnt > 3) begin   // DELAY
                spi_sck <= 0;
                cnt <= 0;
                state <= 20;
            end
            else begin
                cnt <= cnt + 1;
                state <= 19;
            end
        end
        
        20: begin
            spi_sck <= 0;
            state <= 21;
        end
        
        21: begin
            spi_sck <= 0;
            adc_conv <= 0; 
            adc_clk_count <= adc_clk_count + 1;
            //adc_bit_count <= adc_bit_count - 1;
            state <= 22;
        end
        
        22: begin
            spi_sck <= 1;
            state <= 23;
        end
        
        23: begin
            spi_sck <= 1;
            if (adc_clk_count == 34) begin
                adc_sent <= 1;
                //spi_sck <= 0;
                state <= 24;
            end
            
            else if (adc_clk_count <= 2) begin // first two clock where ADC output = Z
                //spi_sck <= 0;
                state <= 20;
            end
            
            else if ((adc_clk_count>2) && (adc_clk_count<=16)) begin // first 14 bits
                //spi_sck <= 0;
                adc_data1[adc_bit_count - 1] <= spi_miso; // output of ADC1
                adc_bit_count <= adc_bit_count - 1;
                state <= 20;
            end
            
            else if ((adc_clk_count > 16) && (adc_clk_count <= 18)) begin // Here ADC output = Z
                //spi_sck <= 0;
                adc_bit_count <= 14;
                state <= 20;
            end
            
            else if ((adc_clk_count > 18) && (adc_clk_count <= 32)) begin // for another 14 bit
                //spi_sck <= 0;
                adc_data2[adc_bit_count - 1] <= spi_miso;
                adc_bit_count <= adc_bit_count - 1;
                state <= 20;
            end
            
            else if (adc_clk_count == 33) begin // 33 clk pulse
                //spi_sck <= 0;
                state <= 20;
            end
        end
        
        24: begin 
            adc_clk_count <= 0;
            adc_bit_count <= 14;
            spi_sck <= 0;
            state <= 25;
        end
        
        25: begin
            spi_sck <= 0;
            adc_sent <= 0;
            // adc_conv <= 1;
            state <= 26;
        end
        
        26: begin
            spi_sck <= 1;
            amp_shdn <= 0;
            state <= 27;
        end
        
        27: begin
            spi_sck <= 1;
            state <= 28;
        end
        
        28: begin
            if (cnt > 4) begin
                spi_sck <= 0;
                state <= 16; // getting ADC output in 2 channels simultaneously
                             // after 34 clock cycle and when adc_conv = 1'b1 again for next propagation
                             
                cnt <= 0;
            end
            else begin
                cnt <= cnt + 1;
                spi_sck <= 0;
                state <= 28;
            end
        end
        endcase
        end
    end
    
endmodule