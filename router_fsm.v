`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.06.2025 22:31:48
// Design Name: 
// Module Name: router_fsm
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


module router_fsm(
        input clk,resetn, packet_valid,  //Indicates that a valid packet is being sent, asserted with the header byte 
        input [1:0] datain, //The 2-bit address part of the incoming data
        input fifo_full,fifo_empty_0,fifo_empty_1,fifo_empty_2,
        input soft_reset_0,soft_reset_1,soft_reset_2,
        input parity_done, // Signal from the register module indicating parity calculation is complete
        input  low_packet_valid, //indicating packet_valid has de-asserted for the current packet 

        output write_enb_reg,detect_add,
        output ld_state, //Asserted in LOAD_DATA state to load payload data to the FIFO
        output laf_state, //Asserted in LOAD_AFTER_FULL state to latch data after a FIFO_FULL_STATE
        output lfd_state,  // Asserted in LOAD_FIRST_DATA state to load the first data byte (header) to the FIFO
        output full_state,rst_int_reg,
        output busy //Indicates the router is occupied and should not accept new incoming data
        );
        
        parameter decode_address     = 4'b0001, // Initial state, looking for a new packet and its address [2].
              wait_till_empty    = 4'b0010, // Router waits here if the target FIFO is not empty [15].
              load_first_data    = 4'b0011, // Loads the header byte into the FIFO [12].
              load_data          = 4'b0100, // Loads payload data bytes into the FIFO [10].
              load_parity        = 4'b0101, // Latches and loads the parity byte into the FIFO [11].
              fifo_full_state    = 4'b0110, // Indicates the selected FIFO is full [11].
              load_after_full    = 4'b0111, // Recovers from FIFO_FULL_STATE and continues loading data [11].
              check_parity_error = 4'b1000; // Checks for packet parity mismatch [13].
              
        reg [3:0] present_state, next_state; // Current and next state registers for the FSM.
        reg [1:0] temp; // Temporary register to store the destination address (2-bit `datain`).
        
        always@(posedge clk)
            begin
                if(~resetn) 
                    temp<=2'b0;
                else if(detect_add) 
                    temp<=datain;  // latch the incoming address datain
            end 
            
        always@(posedge clk)
            begin
                if(!resetn) 
                    present_state<=decode_address; 
                else if (((soft_reset_0) && (temp==2'b00)) || ((soft_reset_1) && (temp==2'b01)) || ((soft_reset_2) && (temp==2'b10)))
                    present_state<=decode_address; 
                else
                    present_state<=next_state; // Otherwise, update the current state to the `next_state` determined by the state machine logic.
            end 
            
            
            always@(*)
            begin
                case(present_state)
                    decode_address: 
                    begin
                        // Transition to `load_first_data` if a valid packet arrives AND its target FIFO is empty.
                        if((packet_valid && (datain==2'b00) && fifo_empty_0)|| // Packet for FIFO 0, and FIFO 0 is empty.
                           (packet_valid && (datain==2'b01) && fifo_empty_1)|| // Packet for FIFO 1, and FIFO 1 is empty.
                           (packet_valid && (datain==2'b10) && fifo_empty_2))   // Packet for FIFO 2, and FIFO 2 is empty.
                            next_state<=load_first_data; // Go to `load_first_data` state [18].
                        // Transition to `wait_till_empty` if a valid packet arrives BUT its target FIFO is NOT empty.
                        else if((packet_valid && (datain==2'b00) && !fifo_empty_0)|| // Packet for FIFO 0, but FIFO 0 is NOT empty.
                                (packet_valid && (datain==2'b01) && !fifo_empty_1)|| // Packet for FIFO 1, but FIFO 1 is NOT empty.
                                (packet_valid && (datain==2'b10) && !fifo_empty_2))   // Packet for FIFO 2, but FIFO 2 is NOT empty.
                            next_state<=wait_till_empty; // Go to `wait_till_empty` state [18].
                        else
                            next_state<=decode_address; 
                    end
        
                    load_first_data: 
                    begin
                        // Unconditionally move to `load_data` in the next clock cycle after loading the header 
                        next_state<=load_data;
                    end
        
                    wait_till_empty: 
                    begin
                        // Remain in `wait_till_empty` until the targeted FIFO becomes empty.
                        if((fifo_empty_0 && (temp==2'b00))|| // If FIFO 0 is empty and it was the target.  clever
                           (fifo_empty_1 && (temp==2'b01))|| // If FIFO 1 is empty and it was the target.
                           (fifo_empty_2 && (temp==2'b10)))   // If FIFO 2 is empty and it was the target.
                            next_state<=load_first_data; // Go to `load_first_data` to start processing the packet [19].
                        else
                            next_state<=wait_till_empty; 
                    end
        
                    load_data: 
                    begin
                        // if the selected FIFO becomes full during data loading.
                        if(fifo_full==1'b1)
                            next_state<=fifo_full_state;    
                        else
                        begin
                            // If the FIFO is not full AND `packet_valid` goes low (indicating end of payload),
                            // move to `load_parity`.
                            if (!fifo_full && !packet_valid)
                                next_state<=load_parity; 
                            else
                                next_state<=load_data; // Otherwise, continue loading data [19].
                        end
                    end
        
                    fifo_full_state: 
                    begin
                        // Transition to `load_after_full` once the FIFO is no longer full --- data has been read out
                        if(fifo_full==0)
                            next_state<=load_after_full; 
                        else
                            next_state<=fifo_full_state;
                    end
        
                    load_after_full: 
                    begin
                        // This state handles resuming data loading after a FIFO full condition.
                        if(!parity_done && low_packet_valid) // If parity is not done, but `packet_valid` went low (end of payload)
                            next_state<=load_parity; 
                        else if(!parity_done && !low_packet_valid) // If parity is not done and `packet_valid` is still high (more payload)
                            next_state<=load_data; 
                        else
                        begin
                            if(parity_done==1'b1) 
                                next_state<=decode_address; 
                            else
                                next_state<=load_after_full; 
                        end
                    end
        
                    load_parity: 
                    begin
                        // Unconditionally move to `check_parity_error` after latching the parity byte [11, 21].
                        next_state<=check_parity_error;
                    end
        
                    check_parity_error: 
                    begin
                        if(!fifo_full) 
                            next_state<=decode_address; 
                        else
                            next_state<=fifo_full_state; 
                    end
        
                    default: 
                        next_state<=decode_address; 
                endcase
            end
            
    assign busy = ((present_state==load_first_data) || (present_state==load_parity) || (present_state==fifo_full_state) ||
                   (present_state==load_after_full) || (present_state==wait_till_empty) || (present_state==check_parity_error)) ? 1 : 0;
                   // `busy` is asserted in states where the router is actively processing a packet or waiting,
                   // indicating that new incoming data should be held 

    // `detect_add` is asserted only in the `decode_address` state to latch the header byte [2].
    assign detect_add = ((present_state==decode_address)) ? 1 : 0;

    // `lfd_state` is asserted only in `load_first_data` to load the header [12].
    assign lfd_state = ((present_state==load_first_data)) ? 1 : 0;

    // `ld_state` is asserted only in `load_data` to load payload bytes [10].
    assign ld_state = ((present_state==load_data)) ? 1 : 0;

    // `write_enb_reg` enables writing to the selected FIFO during data and parity loading [10, 11].
    assign write_enb_reg = ((present_state==load_data) || (present_state==load_after_full) || (present_state==load_parity)) ? 1 : 0;

    // `full_state` is asserted only in `fifo_full_state` [11].
    assign full_state = ((present_state==fifo_full_state)) ? 1 : 0;

    // `laf_state` is asserted only in `load_after_full` [11].
    assign laf_state = ((present_state==load_after_full)) ? 1 : 0;

    // `rst_int_reg` is asserted in `check_parity_error` to reset specific internal registers in `router_reg` [9, 13].
    assign rst_int_reg = ((present_state==check_parity_error)) ? 1 : 0;

endmodule
