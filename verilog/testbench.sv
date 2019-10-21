/*
 * pattern: 12-bit
 * (12-bit)comparator*8ea for one block (96-bit)
 * Total 3 blocks array (96*3=288-bit)
 */

`define ARR_SIZE 288 // number of bits in input array
`define P_SIZE 12 // number of bits in pattern (=number of bits in page)
`define NOB 3 // number of blocks (=comparing epoch)

`define B_SIZE `ARR_SIZE/`NOB // number of bits in a block // 96
`define PPB `B_SIZE/`P_SIZE // number of page comparators per block // 8
`define NOP `ARR_SIZE/`P_SIZE // total number of pages // 24

`define NOP_RANGE_SIZE 5 // integer which can store the range of page number 0~23 (5-bit can store 0~31 integer)
`define NOB_RANGE_SIZE 2 // integer which can store the range of block number 0~2 (2-bit can store 0~3 integer)
`define PPB_RANGE_SIZE 3 // integer which can store the range of block number 0~7 (3-bit can store 0~7 integer)
/*
 * One comparator can compare one page with four page-size patterns
 * In one epoch, HW finds true pages which are equal to patterns in one block
 * After processing all blocks, HW returns an array which consists of the index number of true pages
 */
 

/* testbench.sv */

module find_bit_pattern_tb;
  // Inputs
  reg clk;
  reg rst;
  reg [`ARR_SIZE-1:0] arr;
  reg [`P_SIZE-1:0] pattern1, pattern2, pattern3, pattern4;
  reg [1:0] block_index;
  reg put_global;
   
  // Outputs
  reg [`NOP_RANGE_SIZE:0] global_tpn_arr [0:`NOP-1]; // array of global true page number
  
  find_bit_pattern
  (
    .g_tpn_arr(global_tpn_arr),
    .clk(clk),
    .rst(rst),
    .b_idx(block_index),
    .a(arr),
    .x1(pattern1),
    .x2(pattern2),
    .x3(pattern3),
    .x4(pattern4),
    .put_global_array(put_global)
  );
  
  initial #200 $finish;
  
  initial begin
    forever
      #10 clk = ~clk;
  end
  
  initial
    begin
      $dumpfile("find_bit_pattern.vcd");
      $dumpvars(2,find_bit_pattern);
      // Initialize Inputs
      clk = 1'b0;
      rst = 1'b0;
      put_global = 0;
      #10 
      
      rst = 1'b1;
      pattern1 = 12'h111;
      pattern2 = 12'h222;
      pattern3 = 12'h333;
      pattern4 = 12'h444;
      
      /* Test Input 1 */
      arr = 288'h111_234_567_890_abc_222_333_012____123_234_111_345_444_678_abc_111____666_777_888_111_222_666_000_fff ;
      // TrueP :[ 1   0   0   0   0   1   1   0      0   0   1   0   1   0   0   1      0   0   0   1   1   0   0   0 ]
      // Expected Output(dec): [ 3 4 8 11 13 17 18 23 ]    
      // Expected Output(hex): [ 3 4 8 b  d  11 12 17 ]    
      
      /* Test Input 2 */
      arr = 288'h111_222_222_333_111_222_333_111____123_234_111_345_444_678_abc_111____666_777_888_111_222_666_000_fff ;
      // TrueP :[ 1   1   1   1   1   1   1   1      0   0   1   0   1   0   0   1      0   0   0   1   1   0   0   0 ]
      // Expected Output(dec): [ 3 4 8 11 13 16 17 18 19 20 21 22 23 ]    
      // Expected Output(hex): [ 3 4 8 b  d  10 11 12 13 14 15 16 17 ]    
      
      //#20 
      
      block_index = 2'd0;
      put_global = 1;
      #10
      put_global = 0;
      #30
      
      block_index = 2'd1;
      put_global = 1;
      #10
      put_global = 0;
      #30
      
      block_index = 2'd2;
      put_global = 1;
      #10
      put_global = 0;
      #30
      
      put_global = 1;
      #10
      put_global = 0;
      #30
      
      
      rst = 1'b0;
      
    end
 
endmodule // find_bit_pattern_tb
