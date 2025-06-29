`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.06.2025 22:49:48
// Design Name: 
// Module Name: router_register
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


module router_reg(
    input clk,             
    input resetn,          
    input packet_valid,    
    input [7:0] datain,    
    input fifo_full,       
    input detect_add,      
    input ld_state,        // load data
    input laf_state,       // load after full
    input full_state,      
    input lfd_state,       // load first data
    input rst_int_reg,     

    output reg err,         // asserted on parity mismatch 
    output reg parity_done, // on completion of parity calculation 
    output reg low_packet_valid, 
    output reg [7:0] dout   
);

reg [7:0] hold_header_byte;      
reg [7:0] fifo_full_state_byte;  
reg [7:0] internal_parity;      
reg [7:0] packet_parity_byte;    

// 'parity_done' is high when parity calculation for a packet is considered complete.
always@(posedge clk) begin
    if (!resetn) begin
        parity_done <= 1'b0;
    end else begin
        if (ld_state && !fifo_full && !packet_valid) begin
            // Set 'parity_done' when payload loading is active, FIFO is not full,
            // and 'packet_valid' de-asserts (signaling end of packet before parity byte
            parity_done <= 1'b1;
        end else if (laf_state && low_packet_valid && !parity_done) begin
            // Set 'parity_done' if loading after FIFO full, 'low_packet_valid' is high,
            // and 'parity_done' was previously low. This handles packets that
            // experienced a FIFO full condition 
            parity_done <= 1'b1;
        end else begin
            if (detect_add) begin
                // Reset 'parity_done' when a new packet detection begins 
                parity_done <= 1'b0;
            end
        end
    end
end

// Low Packet Valid Logic
// Indicates if 'packet_valid' has de-asserted for the current packet while 'ld_state' was active.
always@(posedge clk) begin
    if (!resetn) begin
        low_packet_valid <= 1'b0;
    end else begin
        if (rst_int_reg) begin
            //  'rst_int_reg' is generated in check_parity_error state 
            low_packet_valid <= 1'b0;
        end
        if (ld_state == 1'b1 && packet_valid == 1'b0) begin
            // Set 'low_packet_valid' when in the 'load_data' state and 'packet_valid' goes low,
            // indicating the end of the packet payload before the parity byte [9, 13, 14].
            low_packet_valid <= 1'b1;
        end
    end
end

// dout (Data Output) Logic
// Manages which data byte is presented on the 'dout' bus, based on FSM state and FIFO status.
always@(posedge clk) begin
    if (!resetn) begin
        dout <= 8'b0;
    end else begin
        if (detect_add && packet_valid) begin
            // When in the 'decode_address' state and 'packet_valid' is high,
            // the incoming data is latched as the header byte 
            hold_header_byte <= datain;
        end else if (lfd_state) begin
            dout <= hold_header_byte;
        end else if (ld_state && !fifo_full) begin
            dout <= datain;
        end else if (ld_state && fifo_full) begin
            fifo_full_state_byte <= datain;
        end else begin
            if (laf_state) begin
                dout <= fifo_full_state_byte;
            end
        end
    end
end

// Internal Parity Calculation Logic
always@(posedge clk) begin
    if (!resetn) begin
        internal_parity <= 8'b0;
    end else if (lfd_state) begin
        // When the first data (header) is loaded, XOR it with the current internal parity 
        internal_parity <= internal_parity ^ hold_header_byte;
    end else if (ld_state && packet_valid && !full_state) begin
        internal_parity <= internal_parity ^ datain;
    end else begin
        if (detect_add) begin
            // Reset 'internal_parity' when a new packet detection begins 
            internal_parity <= 8'b0;
        end
    end
end

// Packet Parity Byte Latching Logic
always@(posedge clk) begin
    if (!resetn) begin
        packet_parity_byte <= 8'b0;
    end else begin
        if (!packet_valid && ld_state) begin
            packet_parity_byte <= datain;
        end
    end
end

// Error Flag Logic
always@(posedge clk) begin
    if (!resetn) begin
        err <= 1'b0;
    end else begin
        if (parity_done) begin
            if (internal_parity != packet_parity_byte) begin
                // If internal parity does not match the received packet parity
                err <= 1'b1;
            end else begin
                err <= 1'b0;
            end
        end
    end
end

endmodule
