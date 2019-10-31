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

`define NOP_WIDTH 5 // integer which can store the range of page number 0~23 (5-bit can store 0~31 integer)
`define NOB_WIDTH 2 // integer which can store the range of block number 0~2 (2-bit can store 0~3 integer)
`define PPB_WIDTH 3 // integer which can store the range of block number 0~7 (3-bit can store 0~7 integer)
`define B_OFS_WIDTH 6 // integer which can store the range of block offset(in-block bit index) 0~40 (6-bit can store 0~63)
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
  
  wire eq1, eq1_0, eq1_1, eq1_2;
  wire eq2, eq2_0, eq2_1, eq2_2;
  wire eq3, eq3_0, eq3_1, eq3_2;
  wire eq4, eq4_0, eq4_1, eq4_2;
  
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
  
module comparator_block(tpn_arr, tpn_ofs, clk, rst, a_part, b_idx, x1, x2, x3, x4);
  input [`B_SIZE-1:0] a_part;
  input [`P_SIZE-1:0] x1, x2, x3, x4;
  input [`NOB_WIDTH:0] b_idx;
  input clk, rst;
  
  output reg [`NOP_WIDTH*`PPB - 1 : 0] tpn_arr; // array of true page numbers in this block
  output reg [`B_OFS_WIDTH-1:0] tpn_ofs; // bit index(block offset) of true pages in this block // 0~40
  
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
  
  reg [`NOP_WIDTH-1:0] global_tpn;
  reg [2:0] i; // NOP_WIDTH_WIDTH (3-bit can store 0~4)
  
  /* FIFO buffer: insert the numbers(index) of true pages into tpn_arr */
  always @ (posedge clk, negedge rst) begin
    if (!rst) begin global_tpn = 0; tpn_arr = 0; tpn_ofs = 0; end
    else begin
      tpn_ofs = 0;
      if (eq0) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+0; 
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq1) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+1;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq2) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+2;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq3) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+3;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq4) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+4;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq5) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+5;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq6) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+6;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq7) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+7;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
    end
  end
  
endmodule
  
module find_bit_pattern(g_tpn_arr, clk, rst, b_idx, a, x1, x2, x3, x4, put_global_array);
  input clk, rst;
  input [`ARR_SIZE-1:0] a; // input vector
  input [`P_SIZE-1:0] x1, x2, x3, x4; // 4 patterns to compare
  input [`NOB_WIDTH:0] b_idx; // block index
  input put_global_array;
  
  output reg [`NOP_WIDTH*`NOP-1:0] g_tpn_arr; // global(main) array of true page numbers(indices)
  // 4:0 5-bit x 24 -> 119:0 (5*24-1)
  
  reg [`B_SIZE-1:0] a_part; // block-unit part of input vector
  
  always @ (posedge clk, negedge rst) begin
    if (!rst) begin a_part <= 0; end
    else begin 
      case (b_idx)
        2'd0: begin a_part[`B_SIZE-1:0] <= a[`B_SIZE*1-1 : `B_SIZE*0]; end
        2'd1: begin a_part[`B_SIZE-1:0] <= a[`B_SIZE*2-1 : `B_SIZE*1]; end
        2'd2: begin a_part[`B_SIZE-1:0] <= a[`B_SIZE*3-1 : `B_SIZE*2]; end
      endcase
    end
  end
  
  wire [`NOP_WIDTH*`PPB-1 : 0] out_tpn_arr; // array of true page numbers in this block
  wire [`B_OFS_WIDTH-1:0] out_tpn_ofs; // bit index(block offset) of true pages in one block // 0~40
  
  /* Pattern Check in 1 epoch(block) */
  comparator_block b0(out_tpn_arr, out_tpn_ofs, clk, rst, a_part, b_idx, x1, x2, x3, x4);
  
  reg [`NOP_WIDTH*`NOP-1:0] g_tpn_ofs; // bit index(offset) of global tpn array
  // 4:0 5-bit x 24 -> 119:0 (5*24-1)
 
  /* FIFO buffer: insert the output of comparator_block(out_tpn_arr) into g_tpn_arr. g_tpn_arr will have the numbers(indices) of all true pages */
  integer i; // `B_OFS_WIDTH_WIDTH: 6-bit can store 0~40 integer
  always @ (posedge put_global_array, negedge rst) begin
    if (!rst)  begin g_tpn_arr = 0; g_tpn_ofs = 0; end
    else begin
      /*
       * 지금은 page가 총 24개여서 page index가 5-bit(NOP_WIDTH)로 표현되므로 5-bit 단위(5의 배수)로 끊지만, 6144-bit라면 page index가 0~511이므로 NOP_WIDTH가 9-bit가 된다. 
       * 따라서 그때는 9-bit 단위로 끊기게 하는 게 align에 맞다 (이렇게 안해도 상관없지만 의미없는 연산이 추가됨)
       * 실제로는 true page 수가 매우 적으며, 현재 C code 세팅은 1개 아니면 2개이다. (false positive parameter를 어떻게 정하느냐에 따라 1개~n개가 되는데, 지금은 n=2인 셈이다)
       * 즉, 한 epoch(block)에서는 대부분 0개에 가끔 1개, 매우 드물게 2개까지 나오는 셈
       */
      if (out_tpn_ofs != 0) begin
        if (out_tpn_ofs <= 6'd5) begin 
          for (i=0; i<5; i=i+1) begin g_tpn_arr[g_tpn_ofs+i] = out_tpn_arr[i]; end
          g_tpn_ofs = g_tpn_ofs + out_tpn_ofs;
        end
        else if (out_tpn_ofs <= 6'd10) begin
          for (i=0; i<10; i=i+1) begin g_tpn_arr[g_tpn_ofs+i] = out_tpn_arr[i]; end
          g_tpn_ofs = g_tpn_ofs + out_tpn_ofs;
        end
        
        /* 실제 test case에서는 최대 true page 개수가 2개이므로 이 이후는 사실상 수행되지 않는다 */
        else if (out_tpn_ofs <= 6'd15) begin
          for (i=0; i<15; i=i+1) begin g_tpn_arr[g_tpn_ofs+i] = out_tpn_arr[i]; end
          g_tpn_ofs = g_tpn_ofs + out_tpn_ofs;
        end
        else if (out_tpn_ofs <= 6'd40) begin
          for (i=0; i<40; i=i+1) begin g_tpn_arr[g_tpn_ofs+i] = out_tpn_arr[i]; end
          g_tpn_ofs = g_tpn_ofs + out_tpn_ofs;
        end
      end
      
      /*
      // for문에서의 loop 수가 동적으로 결정되면 안 된다.
      for (i=0; i<=40; i=i+1) begin // 이렇게 해도 작동할 것 같긴 한데, 96이라 너무 크니 이렇게 한다면 block size를 줄여야 할 것 같다. // 아니면 out_tpn_ofs가 ~24, ~48, ~72, ~96인지에 따라 4가지 case로 나누어서 넣던지
        g_tpn_arr[g_tpn_ofs+i] = out_tpn_arr[i];
      end
      g_ptn_ofs = g_tpn_ofs + out_tpn_ofs;
      */
      
      /*
      // g_tpn_arr[g_tpn_ofs+out_tpn_ofs-1 : g_tpn_ofs] = out_tpn_arr[out_tpn_ofs-1 : 0]
      for (i=0; i<out_tpn_ofs; i=i+1) begin
        g_tpn_arr[g_tpn_ofs+i] = out_tpn_arr[i];
      end
      g_tpn_ofs = g_tpn_ofs + out_tpn_ofs;
      */
    end
  end
  
  /* Check whether the output is correct. It is not necessary in actual work. */
  wire [`NOP_WIDTH-1:0] ret0, ret1, ret2, ret3, ret4, ret5, ret6, ret7, ret8, ret9, ret10, ret11;
  wire [`NOP_WIDTH-1:0] ret12, ret13, ret14, ret15, ret16, ret17, ret18, ret19, ret20, ret21, ret22, ret23;
  assign ret0[4:0] = g_tpn_arr[5*1-1:5*0];
  assign ret1[4:0] = g_tpn_arr[5*2-1:5*1];
  assign ret2[4:0] = g_tpn_arr[5*3-1:5*2];
  assign ret3[4:0] = g_tpn_arr[5*4-1:5*3];
  assign ret4[4:0] = g_tpn_arr[5*5-1:5*4];
  assign ret5[4:0] = g_tpn_arr[5*6-1:5*5];
  assign ret6[4:0] = g_tpn_arr[5*7-1:5*6];
  assign ret7[4:0] = g_tpn_arr[5*8-1:5*7];
  assign ret8[4:0] = g_tpn_arr[5*9-1:5*8];
  assign ret9[4:0] = g_tpn_arr[5*10-1:5*9];
  assign ret10[4:0] = g_tpn_arr[5*11-1:5*10];
  assign ret11[4:0] = g_tpn_arr[5*12-1:5*11];
  assign ret12[4:0] = g_tpn_arr[5*13-1:5*12];
  assign ret13[4:0] = g_tpn_arr[5*14-1:5*13];
  assign ret14[4:0] = g_tpn_arr[5*15-1:5*14];
  assign ret15[4:0] = g_tpn_arr[5*16-1:5*15];
  assign ret16[4:0] = g_tpn_arr[5*17-1:5*16];
  assign ret17[4:0] = g_tpn_arr[5*18-1:5*17];
  assign ret18[4:0] = g_tpn_arr[5*19-1:5*18];
  assign ret19[4:0] = g_tpn_arr[5*20-1:5*19];
  assign ret20[4:0] = g_tpn_arr[5*21-1:5*20];
  assign ret21[4:0] = g_tpn_arr[5*22-1:5*21];
  assign ret22[4:0] = g_tpn_arr[5*23-1:5*22];
  assign ret23[4:0] = g_tpn_arr[5*24-1:5*23];
endmodule
