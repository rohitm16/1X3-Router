`timescale 1ns / 1ps

module router_fifo #(
    parameter Depth = 16,
    parameter Width = 8
) (
    input clk,
    input resetn,
    input soft_reset,
    input lfd_state,
    input [Width-1:0] data_in,
    input wr_en, rd_en,
    output reg [Width-1:0] data_out,
    output empty, full
);

    // Memory, pointers, and counters
    reg [Width:0] memory [0:Depth-1]; // 9-bit wide to store header flag
    localparam addr_width = $clog2(Depth);
    // reason for addr_width+1 bit is that we will be able to count and store 2^addrwidth as a no 
    // i.e. to store 256 as a no we need 9 bits 
    reg [addr_width:0] count; // Tracks total items
    reg [addr_width-1:0] rd_ptr, wr_ptr;
    reg [5:0] pkt_count; // Tracks bytes remaining in the packet being read
    reg temp_lfd; // Registered version of lfd_state

    // Status flags
    assign empty = (count == 0);
    assign full = (count == Depth);
    
    // Write and read enable signals
    wire do_write = wr_en && !full;
    wire do_read = rd_en && !empty;

    // --- LOGIC BLOCKS ---

    // 1. Register the lfd_state input
    always@(posedge clk) begin
        if(!resetn)
            temp_lfd <= 1'b0;
        else
            temp_lfd <= lfd_state;
    end

    // 2. Write Logic
    always@(posedge clk) begin
        if(do_write)
            memory[wr_ptr] <= {temp_lfd, data_in};
    end

    // 3. Pointer and Main Counter Logic
    always@(posedge clk or negedge resetn) begin
        if(!resetn || soft_reset) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count <= 0;
        end else begin
            if(do_write && !do_read) begin // Write only
                wr_ptr <= wr_ptr + 1;
                count <= count + 1;
            end else if(!do_write && do_read) begin // Read only
                rd_ptr <= rd_ptr + 1;
                count <= count - 1;
            end else if(do_write && do_read) begin // Simultaneous Read and Write
                wr_ptr <= wr_ptr + 1;
                rd_ptr <= rd_ptr + 1;
                // count remains the same
            end
        end
    end

    // 4. Read and Packet Counter Logic
    always@(posedge clk) begin
        if(!resetn) begin
            data_out <= 8'd0;
            pkt_count <= 0;
        end else if(soft_reset) begin
            data_out <= 8'bz;
            pkt_count <= 0;
        end else if(do_read) begin
            data_out <= memory[rd_ptr][7:0]; // Output the 8-bit data
            // Check if it's a header
            if(memory[rd_ptr][8]) begin
                // Load packet counter with payload length + parity
                pkt_count <= memory[rd_ptr][7:2] + 1'b1;
            end else if(pkt_count != 0) begin
                pkt_count <= pkt_count - 1;
            end
        end

        // Tri-state the bus after the packet is read
        if(pkt_count == 1 && do_read) begin
             data_out <= 8'bz;
        end
    end

endmodule
