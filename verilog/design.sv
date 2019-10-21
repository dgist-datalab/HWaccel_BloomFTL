/*
 * pattern: 12-bit
 * (12-bit)comparator*8ea for one block (96-bit)
 * Total 3 blocks array (96*3=288-bit)
 */

`define ARR_SIZE 288 // number of bits in input array
`define P_SIZE 12 // number of bits in pattern (=number of bits in page)
`define NOB 3 // number of blocks (=comparing epoch)

`define B_SIZE `ARR_SIZE/`NOB // number of bits in a block // 96
`define PPB `B_SIZE/`P_SIZE // number of comparators per block // 8
`define NOP `ARR_SIZE/`P_SIZE // total number of pages // 24

`define NOP_RANGE_SIZE 5 // integer which can store the range of page number 0~23 (5-bit can store 0~31 integer)
`define NOB_RANGE_SIZE 2 // integer which can store the range of block number 0~2 (2-bit can store 0~3 integer)
`define PPB_RANGE_SIZE 3 // integer which can store the range of block number 0~7 (3-bit can store 0~7 integer)
/*
 * One comparator can compare one page with four page-size patterns
 * In one epoch, HW finds true pages which are equal to patterns in one block
 * After processing all blocks, HW returns an array which consists of the index number of true pages
 */


/* design.sv */

module comparator_4bit (
  input [3:0]a, 
  input [3:0]b, 
  output eq
);
  wire a00, a01, a10, a11;
  xor a1(a00, a[0], b[0]);
  xor a2(a01, a[1], b[1]);
  xor a3(a10, a[2], b[2]);
  xor a4(a11, a[3], b[3]);
  
  nor a5(eq, a00, a01, a10, a11);
endmodule

module comparator_page(eq, a, b1, b2, b3, b4);
  input [`P_SIZE-1:0]a;
  input [`P_SIZE-1:0]b1, b2, b3, b4;
  output eq;
  
  wire eq1_0, eq1_1, eq1_2;
  wire eq2_0, eq2_1, eq2_2;
  wire eq3_0, eq3_1, eq3_2;
  wire eq4_0, eq4_1, eq4_2;
  
  /* compare page(12-bits) with 4 inputs(patterns) */
  comparator_4bit fbc1_1(a[3:0], b1[3:0], eq1_0);
  comparator_4bit fbc1_2(a[7:4], b1[7:4], eq1_1);
  comparator_4bit fbc1_3(a[11:8], b1[11:8], eq1_2);
  
  comparator_4bit fbc2_1(a[3:0], b2[3:0], eq2_0);
  comparator_4bit fbc2_2(a[7:4], b2[7:4], eq2_1);
  comparator_4bit fbc2_3(a[11:8], b2[11:8], eq2_2);
  
  comparator_4bit fbc3_1(a[3:0], b3[3:0], eq3_0);
  comparator_4bit fbc3_2(a[7:4], b3[7:4], eq3_1);
  comparator_4bit fbc3_3(a[11:8], b3[11:8], eq3_2);
  
  comparator_4bit fbc4_1(a[3:0], b4[3:0], eq4_0);
  comparator_4bit fbc4_2(a[7:4], b4[7:4], eq4_1);
  comparator_4bit fbc4_3(a[11:8], b4[11:8], eq4_2);
  and a1(eq1, eq1_0, eq1_1, eq1_2);
  and a2(eq2, eq2_0, eq2_1, eq2_2);
  and a3(eq3, eq3_0, eq3_1, eq3_2);
  and a4(eq4, eq4_0, eq4_1, eq4_2);
  
  or o1(eq, eq1, eq2, eq3, eq4);
endmodule

module comparator_block(tpn_arr, tpn_cnt, clk, rst, a_part, b_idx, x1, x2, x3, x4);
  input [`B_SIZE-1:0] a_part;
  input [`P_SIZE:0] x1, x2, x3, x4;
  input [`NOB_RANGE_SIZE:0] b_idx;
  input clk, rst;
  
  output reg [`NOP_RANGE_SIZE:0] tpn_arr [0:`PPB-1]; // array of true page numbers in this block
  output reg [`PPB_RANGE_SIZE:0] tpn_cnt; // # of true pages in this block
  
  wire eq0, eq1, eq2, eq3, eq4, eq5, eq6, eq7;
  
  /* Compare each pages with 4 patterns */
  comparator_page p0(eq0, a_part[`P_SIZE*1-1:`P_SIZE*0], x1, x2, x3, x4);
  comparator_page p1(eq1, a_part[`P_SIZE*2-1:`P_SIZE*1], x1, x2, x3, x4);
  comparator_page p2(eq2, a_part[`P_SIZE*3-1:`P_SIZE*2], x1, x2, x3, x4);
  comparator_page p3(eq3, a_part[`P_SIZE*4-1:`P_SIZE*3], x1, x2, x3, x4);
  comparator_page p4(eq4, a_part[`P_SIZE*5-1:`P_SIZE*4], x1, x2, x3, x4);
  comparator_page p5(eq5, a_part[`P_SIZE*6-1:`P_SIZE*5], x1, x2, x3, x4);
  comparator_page p6(eq6, a_part[`P_SIZE*7-1:`P_SIZE*6], x1, x2, x3, x4);
  comparator_page p7(eq7, a_part[`P_SIZE*8-1:`P_SIZE*7], x1, x2, x3, x4);
  
  /* FIFO buffer: insert the numbers(index) of true pages into tpn_arr */
  always @ (posedge clk, negedge rst) begin
    if (!rst) tpn_cnt = 0;
    else begin
      tpn_cnt = 0;
      if (eq0) begin tpn_arr[tpn_cnt] = b_idx*`PPB + 0; tpn_cnt = tpn_cnt+1; end
      if (eq1) begin tpn_arr[tpn_cnt] = b_idx*`PPB + 1; tpn_cnt = tpn_cnt+1; end
      if (eq2) begin tpn_arr[tpn_cnt] = b_idx*`PPB + 2; tpn_cnt = tpn_cnt+1; end
      if (eq3) begin tpn_arr[tpn_cnt] = b_idx*`PPB + 3; tpn_cnt = tpn_cnt+1; end
      if (eq4) begin tpn_arr[tpn_cnt] = b_idx*`PPB + 4; tpn_cnt = tpn_cnt+1; end
      if (eq5) begin tpn_arr[tpn_cnt] = b_idx*`PPB + 5; tpn_cnt = tpn_cnt+1; end
      if (eq6) begin tpn_arr[tpn_cnt] = b_idx*`PPB + 6; tpn_cnt = tpn_cnt+1; end
      if (eq7) begin tpn_arr[tpn_cnt] = b_idx*`PPB + 7; tpn_cnt = tpn_cnt+1; end
    end
  end
  
endmodule
  
  
module find_bit_pattern(g_tpn_arr, clk, rst, b_idx, a, x1, x2, x3, x4, put_global_array);
  input clk, rst;
  input [`ARR_SIZE-1:0] a; // input vector
  input [`P_SIZE-1:0] x1, x2, x3, x4; // 4 patterns to compare
  input [`NOB_RANGE_SIZE:0] b_idx; // block index
  input put_global_array;
  
  output reg [`NOP_RANGE_SIZE:0] g_tpn_arr [0:`NOP-1]; // global(main) array of true page numbers(indices)
  
  reg [`B_SIZE-1:0] a_part; // block-unit part of input vector
  
  always @ (posedge clk, negedge rst) begin
    if (!rst) g_tpn_arr[0] <= 0;
    else begin 
      case (b_idx)
        2'd0: begin a_part[`B_SIZE-1:0] <= a[`B_SIZE*1-1 : `B_SIZE*0]; end
        2'd1: begin a_part[`B_SIZE-1:0] <= a[`B_SIZE*2-1 : `B_SIZE*1]; end
        2'd2: begin a_part[`B_SIZE-1:0] <= a[`B_SIZE*3-1 : `B_SIZE*2]; end
      endcase
    end
  end
  
  
  reg [`NOP_RANGE_SIZE:0] out_tpn_arr [0:`PPB-1]; // array of true page numbers in one block
  wire [`PPB_RANGE_SIZE:0] out_tpn_cnt; // # of true pages in one block
  
  /* Pattern Check in 1 epoch(block) */
  comparator_block b0(out_tpn_arr, out_tpn_cnt, clk, rst, a_part, b_idx, x1, x2, x3, x4);
  
  reg [`NOP_RANGE_SIZE:0] g_tpn_cnt;
  
  /* FIFO buffer: insert the output of comparator_block(out_tpn_arr) into g_tpn_arr. g_tpn_arr will have the numbers(indices) of all true pages */
  always @ (posedge put_global_array, negedge rst) begin
    if (!rst)  begin g_tpn_cnt <= 0; end
    else begin
      case (out_tpn_cnt) // 0 ~ 8(=PPB)
        0: begin g_tpn_cnt = g_tpn_cnt; end
        1: begin 
          g_tpn_arr[g_tpn_cnt] = out_tpn_arr[0]; 
          g_tpn_cnt = g_tpn_cnt+1; end
        2: begin 
          g_tpn_arr[g_tpn_cnt] = out_tpn_arr[0]; 
          g_tpn_arr[g_tpn_cnt+1] = out_tpn_arr[1]; 
          g_tpn_cnt = g_tpn_cnt+2; end
        3: begin 
          g_tpn_arr[g_tpn_cnt] = out_tpn_arr[0]; 
          g_tpn_arr[g_tpn_cnt+1] = out_tpn_arr[1]; 
          g_tpn_arr[g_tpn_cnt+2] = out_tpn_arr[2]; 
          g_tpn_cnt = g_tpn_cnt+3; end
        4: begin 
          g_tpn_arr[g_tpn_cnt] = out_tpn_arr[0]; 
          g_tpn_arr[g_tpn_cnt+1] = out_tpn_arr[1]; 
          g_tpn_arr[g_tpn_cnt+2] = out_tpn_arr[2]; 
          g_tpn_arr[g_tpn_cnt+3] = out_tpn_arr[3]; 
          g_tpn_cnt = g_tpn_cnt+4; end
        5: begin 
          g_tpn_arr[g_tpn_cnt] = out_tpn_arr[0]; 
          g_tpn_arr[g_tpn_cnt+1] = out_tpn_arr[1]; 
          g_tpn_arr[g_tpn_cnt+2] = out_tpn_arr[2]; 
          g_tpn_arr[g_tpn_cnt+3] = out_tpn_arr[3]; 
          g_tpn_arr[g_tpn_cnt+4] = out_tpn_arr[4]; 
          g_tpn_cnt = g_tpn_cnt+5; end
        6: begin 
          g_tpn_arr[g_tpn_cnt] = out_tpn_arr[0]; 
          g_tpn_arr[g_tpn_cnt+1] = out_tpn_arr[1]; 
          g_tpn_arr[g_tpn_cnt+2] = out_tpn_arr[2]; 
          g_tpn_arr[g_tpn_cnt+3] = out_tpn_arr[3]; 
          g_tpn_arr[g_tpn_cnt+4] = out_tpn_arr[4]; 
          g_tpn_arr[g_tpn_cnt+5] = out_tpn_arr[5]; 
          g_tpn_cnt = g_tpn_cnt+6; end
        7: begin 
          g_tpn_arr[g_tpn_cnt] = out_tpn_arr[0]; 
          g_tpn_arr[g_tpn_cnt+1] = out_tpn_arr[1]; 
          g_tpn_arr[g_tpn_cnt+2] = out_tpn_arr[2]; 
          g_tpn_arr[g_tpn_cnt+3] = out_tpn_arr[3]; 
          g_tpn_arr[g_tpn_cnt+4] = out_tpn_arr[4]; 
          g_tpn_arr[g_tpn_cnt+5] = out_tpn_arr[5]; 
          g_tpn_arr[g_tpn_cnt+6] = out_tpn_arr[6]; 
          g_tpn_cnt = g_tpn_cnt+7; end
        8: begin 
          g_tpn_arr[g_tpn_cnt] = out_tpn_arr[0]; 
          g_tpn_arr[g_tpn_cnt+1] = out_tpn_arr[1]; 
          g_tpn_arr[g_tpn_cnt+2] = out_tpn_arr[2]; 
          g_tpn_arr[g_tpn_cnt+3] = out_tpn_arr[3]; 
          g_tpn_arr[g_tpn_cnt+4] = out_tpn_arr[4]; 
          g_tpn_arr[g_tpn_cnt+5] = out_tpn_arr[5]; 
          g_tpn_arr[g_tpn_cnt+6] = out_tpn_arr[6]; 
          g_tpn_arr[g_tpn_cnt+7] = out_tpn_arr[7]; 
          g_tpn_cnt = g_tpn_cnt+8; end
      endcase
    end
  end
  
  
  /* Check whether the output is correct. It is not necessary in actual work. */
  reg [`NOP_RANGE_SIZE:0] ret0, ret1, ret2, ret3, ret4, ret5, ret6, ret7, ret8, ret9, ret10, ret11;
  reg [`NOP_RANGE_SIZE:0] ret12, ret13, ret14, ret15, ret16, ret17, ret18, ret19, ret20, ret21, ret22, ret23;
    assign ret0 = g_tpn_arr[0];
    assign ret1 = g_tpn_arr[1];
    assign ret2 = g_tpn_arr[2];
    assign ret3 = g_tpn_arr[3];
    assign ret4 = g_tpn_arr[4];
    assign ret5 = g_tpn_arr[5];
    assign ret6 = g_tpn_arr[6];
    assign ret7 = g_tpn_arr[7];
    assign ret8 = g_tpn_arr[8];
    assign ret9 = g_tpn_arr[9];
    assign ret10 = g_tpn_arr[10];
    assign ret11 = g_tpn_arr[11];
    assign ret12 = g_tpn_arr[12];
    assign ret13 = g_tpn_arr[13];
    assign ret14 = g_tpn_arr[14];
    assign ret15 = g_tpn_arr[15];
    assign ret16 = g_tpn_arr[16];
    assign ret17 = g_tpn_arr[17];
    assign ret18 = g_tpn_arr[18];
    assign ret19 = g_tpn_arr[19];
    assign ret20 = g_tpn_arr[20];
    assign ret21 = g_tpn_arr[21];
    assign ret22 = g_tpn_arr[22];
    assign ret23 = g_tpn_arr[23];
      
endmodule
