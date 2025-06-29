`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.06.2025 23:29:47
// Design Name: 
// Module Name: router_fifo
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


module router_fifo(
    input clk,          
    input resetn,       
    input soft_reset,   
    input write_enb,   
    input read_enb,     
    input lfd_state,    // Indicates if the current byte is a header byte (from FSM)
    input [7:0]datain,  // 8-bit input data

    output reg full,    
    output reg empty,   
    output reg [7:0]dataout 
);

    // Internal Data types
    reg [3:0]read_ptr,write_ptr; // 4-bit pointers for 16-depth FIFO 
    reg [5:0]count;              // Counter for payload length + parity (up to 63 bytes)
    reg [8:0]fifo[15:0];         // 9-bit wide, 16-depth memory for FIFO (0 to 15) 
                                 // The 9th bit (fifo[i][29]) stores the header indicator.
    integer i;                   
    reg temp;                    // Temporary storage for lfd_state (9th bit for header)
    reg [4:0] incrementer;       // Tracks current occupancy of the FIFO (0 to 15)

    // lfd_state (Header Bit Control)
    // This logic captures the lfd_state signal to be used as the 9th bit
    // when data is written into the FIFO.
    always@(posedge clk)
    begin
      if(!resetn)
        temp<=1'b0; 
      else
        temp<=lfd_state; // Otherwise, capture the current lfd_state
    end

    // This block tracks the number of bytes currently stored in the FIFO.
    always @(posedge clk )
    begin
      if( !resetn )
        incrementer <= 0; 
      else if( (!full && write_enb) && ( !empty && read_enb ) )
        incrementer<= incrementer; // simultaneous read/write, 
      else if( !full && write_enb )
        incrementer <= incrementer + 1; 
      else if( !empty && read_enb )
        incrementer <= incrementer - 1;
      else
        incrementer <= incrementer; 
    end

    // Full and Empty Logic (Status Signals)
    always @(incrementer)
    begin
      if(incrementer==0) // If incrementer is 0, FIFO is empty
        empty = 1; 
      else
        empty = 0;

      if(incrementer==4'b1111) // If incrementer is 15 (max for 16-depth), 
        full = 1;  
      else
        full = 0;
    end

    // FIFO Write Logic
    always@(posedge clk)
    begin
      if(!resetn || soft_reset) 
      begin
        for(i=0;i<16;i=i+1)
          fifo[i]<=0; 
      end
      else if(write_enb && !full) 
        {fifo[write_ptr[3:0]][8],fifo[write_ptr[3:0]][7:0]}<={temp,datain};  //temp=1 for header data and 0 for other data
       
    end

    always@(posedge clk)
    begin
      if(!resetn)
        dataout<=8'd0; 
      else if(soft_reset)
        dataout<=8'bzz; // On soft reset (time-out condition), dataout is tri-stated (High-Z) 
      else
      begin
        if(read_enb && !empty) 
          dataout<=fifo[read_ptr[3:0]]; 
        if(count==6'd0 && read_enb) // If internal counter reaches 0 (packet completely read)
          dataout<=8'bz; 
      end
    end

    // Counter Logic (Payload Length Tracking)
    always@(posedge clk)
    begin
      if(read_enb && !empty) 
      begin
        if(fifo[read_ptr[3:0]][8])  //initialize after cheking for header detector bit
          //  The value loaded into count is derived from bits [7:2] of the header byte (fifo[read_ptr[3:0]][7:2]) plus 1'b
          count<=fifo[read_ptr[3:0]][7:2]+1'b1;
        else if(count!=6'd0) 
          count<=count-1'b1; // Decrement counter for subsequent payload/parity bytes 
      end
    end

    always@(posedge clk)
    begin
      if(!resetn || soft_reset) 
      begin
        read_ptr=5'd0; 
        write_ptr=5'd0; 
      end
      else
      begin
        if(write_enb && !full) 
          write_ptr=write_ptr+1'b1; 
        if(read_enb && !empty) 
          read_ptr=read_ptr+1'b1; 
      end
    end

endmodule