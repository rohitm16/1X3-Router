`timescale 1ns / 1ps


module router_synchronizer(
    input clk,
    input resetn,
    // From FSM and Register modules
    input detect_add,
    input write_enb_reg,
    input [1:0] datain,
    // From the three FIFOs
    input read_enb_0, read_enb_1, read_enb_2,
    input empty_0, empty_1, empty_2,
    input full_0, full_1, full_2,
    // To the three FIFOs
    output reg [2:0] write_enb,
    output reg soft_reset_0, soft_reset_1, soft_reset_2,
    // To the FSM
    output reg fifo_full,
    // To the external world
    output wire vld_out_0, vld_out_1, vld_out_2
);


    // This register latches and holds the destination address for the
    // entire duration of the packet routing. This is crucial because
    // 'datain' changes every cycle, but we need to remember the target FIFO.
    reg [1:0] temp;

    // Three separate counters, one for each output channel, to track timeouts.
    reg [4:0] count0, count1, count2;


    always@(posedge clk)
    begin
        if(!resetn)
            temp <= 2'd0;
        // When the FSM asserts 'detect_add', it means a new packet has arrived.
        // We latch the destination address from 'datain' into our 'temp' register.
        else if(detect_add)
            temp <= datain;
    end


    // This is combinational logic that uses the latched address ('temp')
    // to route signals between the FSM and the correct FIFO.

    // Route the 'full' status from the selected FIFO to the FSM.
    always@(*)
    begin
        case(temp)
            2'b00: fifo_full = full_0; 
            2'b01: fifo_full = full_1; 
            2'b10: fifo_full = full_2; 
            default: fifo_full = 1'b0;
        endcase
    end

    // Route the 'write_enb_reg' command from the FSM to the selected FIFO.
    always@(*)
    begin
        if(write_enb_reg)
        begin
            case(temp)
                // enabling the write for only one FIFO(one hot).
                2'b00: write_enb = 3'b001; 
                2'b01: write_enb = 3'b010; 
                2'b10: write_enb = 3'b100; 
                default: write_enb = 3'b000;
            endcase
        end
        else
            write_enb = 3'b000; // If FSM is not enabling write, nobody writes.
    end


    // An output port is considered valid if its FIFO is not empty.
    assign vld_out_0 = !empty_0;
    assign vld_out_1 = !empty_1;
    assign vld_out_2 = !empty_2;



    // Timeout logic for Channel 0
    always@(posedge clk)
    begin
        if(!resetn)
            count0 <= 5'b0;
        // If data is valid but the receiver is NOT reading...
        else if(vld_out_0 && !read_enb_0)
        begin
            // ...and the counter reaches 30
            if(count0 == 5'b11110)
            begin
                // ...trigger a soft reset for one cycle and clear the counter.
                soft_reset_0 <= 1'b1;
                count0 <= 5'b0;
            end
            else
            begin
                // ...otherwise, just keep counting.
                count0 <= count0 + 1'b1;
                soft_reset_0 <= 1'b0;
            end
        end
        // If the receiver starts reading or the FIFO becomes empty, reset the counter.
        else
            count0 <= 5'd0;
    end

    // Timeout logic for Channel 1 
    always@(posedge clk)
    begin
        if(!resetn)
            count1 <= 5'b0;
        else if(vld_out_1 && !read_enb_1)
        begin
            if(count1 == 5'b11110)
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
        else
            count1 <= 5'd0;
    end

    // Timeout logic for Channel 2 
    always@(posedge clk)
    begin
        if(!resetn)
            count2 <= 5'b0;
        else if(vld_out_2 && !read_enb_2)
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
        else
            count2 <= 5'd0;
    end

endmodule

