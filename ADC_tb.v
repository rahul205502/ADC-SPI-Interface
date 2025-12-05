`timescale 1ns/1ps

module adc_tb;     
    // Clock Generation (50 MHz)
    reg clk;
    reg enable;
    reg spi_miso; // ADC output and input to master

    wire clk_out, a1, a2, spi_sck;
    wire [13:0] adc_data1, adc_data2;
    wire [33:0] adc_data;
    
    wire amp_cs_w;
    wire adc_conv_w;
    wire spi_mosi_w;
    wire amp_shdn_w;
     
    ADC2 dut (
        .clk(clk),
        .enable(enable),
        .spi_miso(spi_miso),
        .clk_out(clk_out),
        .a1(a1),
        .a2(a2),
        .spi_sck(spi_sck),
        .amp_cs(amp_cs_w),      // Connect to wire
        .adc_conv(adc_conv_w),  // Connect to wire
        .spi_mosi(spi_mosi_w),  // Connect to wire
        .amp_shdn(amp_shdn_w),  // Connect to wire
        .spi_ss_b(),
        .sf_ce0(),
        .fpga_init_b(),
        .dac_cs(),
        .adc_data1(adc_data1),
        .adc_data2(adc_data2),
        .adc_data(adc_data)
    );

     always #10 clk = ~clk;   // 50 MHz (Period = 20 ns)
     
    reg [13:0] e1 = 14'b00001010001001;
    reg [13:0] e2 = 14'b00001101101001;
    
    integer idx1, idx2;

    always @(posedge spi_sck) begin
        if (dut.adc_clk_count > 2 && dut.adc_clk_count <= 16) begin
            if (idx1 >= 0) begin
                spi_miso <= e1[idx1];
                idx1 = idx1 - 1;
            end
        end 
        
        else if (dut.adc_clk_count > 18 && dut.adc_clk_count <= 32) begin
            if (idx2 >= 0) begin
                spi_miso <= e2[idx2];
                idx2 = idx2 - 1;
            end
        end 
        
        else begin
            spi_miso <= 0;
        end
    end

     
initial begin
        $dumpfile("adc_wave.vcd");
        $dumpvars(0, adc_tb);

        clk = 0;
        enable = 1;
        spi_miso = e1[0];
        idx1 = 13; 
        idx2 = 13;

        #100; enable = 0;

        #119240;
        
        $display("\n--- Simulation Complete ---");
        if (adc_data1 === e1 && adc_data2 === e2) begin
            $display("*** PASS: ADC words match expected ***\n");
            $display("ADC_DATA1 (Received): %b (Dec: %d)", adc_data1, adc_data1);
            $display("ADC_DATA2 (Received): %b (Dec: %d)", adc_data2, adc_data2);
            $display("E1 (Expected):        %b (Dec: %d)", e1, e1);
            $display("E2 (Expected):        %b (Dec: %d)", e2, e2);
        end else begin
            $display("*** FAIL ***\n");
            $display("E1 (Expected):        %b (Dec: %d)", e1, e1);
            $display("Got1 (Received):      %b (Dec: %d)", adc_data1, adc_data1);
            $display("E2 (Expected):        %b (Dec: %d)", e2, e2);
            $display("Got2 (Received):      %b (Dec: %d)", adc_data2, adc_data2);
        end

        $finish;
    end

endmodule