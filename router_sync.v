`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.06.2025 10:45:39
// Design Name: 
// Module Name: router_sync
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module router_sync(
    input clk,             
    input resetn,          
    input detect_add,      //  indicate address 
    input write_enb_reg,   

    input read_enb_0,
    input read_enb_1,
    input read_enb_2,
    input empty_0,
    input empty_1,
    input empty_2,
    input full_0,
    input full_1,
    input full_2,

    input [1:0]datain,     

    output wire vld_out_0,
    output wire vld_out_1,
    output wire vld_out_2,

    // 3-bit write enable signal to select and enable writing to a specific FIFO 
    output reg [2:0]write_enb,
    output reg fifo_full,

    output reg soft_reset_0,
    output reg soft_reset_1,
    output reg soft_reset_2
);

// Internal register to store the 2-bit selected FIFO address (00, 01, or 10) 
reg [1:0]temp;
// 5-bit counters for each FIFO to track timeout for soft reset 
reg [4:0]count0,count1,count2;

// This block latches the 2-bit address from 'datain' into the 'temp' register 
// The 'temp' value then determines which FIFO is currently being addressed 
always@(posedge clk)
begin
    if(!resetn)
        temp <= 2'd0;
    else if(detect_add)
        temp<=datain;
end

always@(*)
begin
    case(temp)
        2'b00: fifo_full = full_0; 
        2'b01: fifo_full = full_1; 
        2'b10: fifo_full = full_2; 
        default: fifo_full = 0;    
    endcase
end

always@(*)
begin
    if(write_enb_reg)
    begin
        case(temp)
            2'b00: write_enb = 3'b001; // Enables write for FIFO_0
            2'b01: write_enb = 3'b010; // Enables write for FIFO_1
            2'b10: write_enb = 3'b100; // Enables write for FIFO_2
            default: write_enb = 3'b000; // No FIFO enabled for writing if address is invalid
        endcase
    end
    else
        write_enb = 3'b000;
end

assign vld_out_0 = !empty_0; 
assign vld_out_1 = !empty_1; 
assign vld_out_2 = !empty_2; 

// A 'soft_reset_X' signal is asserted if the corresponding 'read_enb_X' signal
// is *not* asserted within 30 clock cycles of 'vld_out_X' being asserted 
always@(posedge clk)
begin
    if(!resetn)
        count0 <= 5'b0;
    else if(vld_out_0)
    begin
        if(!read_enb_0)
        begin
            if(count0 == 5'b11110) // 30 in decimal [11, 12]
            begin
                // If the counter reaches 30, a timeout occurs 
                soft_reset_0 <= 1'b1; 
                count0 <= 1'b0;       
            end
            else
            begin
                count0 <= count0 + 1'b1; 
                soft_reset_0 <= 1'b0;    
            end
        end
        else
            // If data is being read 
            count0 <= 5'd0;
    end
    else
        // If no valid data is available 
        count0 <= 5'd0;
end

always@(posedge clk)
begin
    if(!resetn)
        count1 <= 5'b0;
    else if(vld_out_1)
    begin
        if(!read_enb_1)
        begin
            if(count1 == 5'b11110) // 30 in decimal [14]
            begin
                soft_reset_1 <= 1'b1;
                count1 <= 1'b0;
            end
            else
            begin
                count1 <= count1 + 1'b1;
                soft_reset_1 <= 1'b0;
            end
        end
        else count1 <= 5'd0;
    end
    else count1 <= 5'd0;
end

always@(posedge clk)
begin
    if(!resetn)
        count2 <= 5'b0;
    else if(vld_out_2)
    begin
        if(!read_enb_2)
        begin
            if(count2 == 5'b11110) 
            begin
                soft_reset_2 <= 1'b1;
                count2 <= 1'b0;
            end
            else
            begin
                count2 <= count2 + 1'b1;
                soft_reset_2 <= 1'b0;
            end
        end
        else count2 <= 5'd0;
    end
    else count2 <= 5'd0;
end

endmodule