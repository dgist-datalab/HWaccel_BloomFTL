/*
 * pattern: 12-bit
 * (12-bit)comparator*32ea for one block (384-bit)
 * Total 128 blocks array (384*128=49152-bit)
 *
 * 4096 * 12 = 49152
 * PPB=64, NOB=64, NOP=4096
 */

`define NOP 4096 // total number of pages // 4096
`define P_SIZE 12 // number of bits in pattern (=number of bits in page)
`define ARR_SIZE ((`NOP)*(`P_SIZE)) // number of bits in input array (4096 page * 12-bit) // 49152

`define PPB 64 // number of page comparators per block
`define NOB ((`NOP)/(`PPB)) // number of blocks (=comparing epoch) // 64
`define B_SIZE ((`ARR_SIZE)/(`NOB)) // number of bits in a block // 768

`define NOP_WIDTH 12 // integer which can store the range of page number 0~4095 (12-bit can store 0~4095 integer)
`define NOB_WIDTH 6 // integer which can store the range of block number 0~63 (6-bit can store 0~63 integer)
`define PPB_WIDTH 6 // integer which can store the range of block number 0~63 (6-bit can store 0~63 integer)

`define B_OFS_WIDTH 10 // integer which can store the range of block offset(in-block bit index) 0~768(=0 ~ NOP_WIDTH*PPB) (10-bit can store 0~1023)

`define MAX_TPN_NUM 8 // number of true pages are from 1 to 8
`define MAX_TPN_NUM_WIDTH 4 // integer which can store the range of max tpn number 0~8 (4-bit can store 0~15)

`define NUM_PATT_WIDTH 3 // integer which can store 000, 001, 011, 111 and 1~4 (3-bit can store 0~7

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

module comparator_page(eq, a, k, b1, b2, b3, b4);
  input [`P_SIZE-1:0]a;
  input [`P_SIZE-1:0]b1, b2, b3, b4;
  input [`NUM_PATT_WIDTH-1:0] k; // number of real patterns
  output eq;
  
  wire eq1, eq1_0, eq1_1, eq1_2;
  wire eq2, eq2_0, eq2_1, eq2_2;
  wire eq3, eq3_0, eq3_1, eq3_2;
  wire eq4, eq4_0, eq4_1, eq4_2;
  
  wire eq2_, eq3_, eq4_;
  
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
  and a2(eq2_, eq2_0, eq2_1, eq2_2);
  and a3(eq3_, eq3_0, eq3_1, eq3_2);
  and a4(eq4_, eq4_0, eq4_1, eq4_2);
  
  /* np=1 -> k=000 -> eq1만 그대로, eq2,3,4는 0으로
   * np=2 -> k=001 -> eq1,2만 그대로, eq3,4는 0으로
   * np=3 -> k=011 -> eq1,2,3만 그대로, eq4는 0으로
   * np=4 -> k=111 -> eq1,2,3,4 다 그대로
   */
  and r2(eq2, eq2_, k);
  and r3(eq3, eq3_, k>>1);
  and r4(eq4, eq4_, k>>2);
  
  or o1(eq, eq1, eq2, eq3, eq4);
endmodule





module comparator_block(eq_list, clk, rst, a_part, b_idx, k, x1, x2, x3, x4, o1,o2,o3,o4,o5,o6,o7,o8, switch_on);
  input [`B_SIZE-1:0] a_part;
  input [`P_SIZE-1:0] x1, x2, x3, x4;
  input [`NOB_WIDTH:0] b_idx;
  input clk, rst;
  input [`NUM_PATT_WIDTH-1:0] k;
  
  output [`PPB-1:0] eq_list;
  output [`PPB_WIDTH-1:0] o1, o2, o3, o4, o5, o6, o7, o8;
  output [`MAX_TPN_NUM-1:0] switch_on;
  
  wire [`PPB-1:0] eq;
  
  /* Compare each pages with 4 patterns */
  comparator_page p [`PPB-1:0] (eq, a_part, k, x1, x2, x3, x4);
  
  reg [`PPB_WIDTH-1:0] location [0:`MAX_TPN_NUM-1];
  reg [`MAX_TPN_NUM-1:0] on;
  integer iter;
  integer j;
  always @ (posedge clk, negedge rst) begin // clk.가 아니라 2번째 clk posedge일 때만 하도록 하는 게 낫지 않을까?
    if (!rst) begin 
      location[0] = 0; location[1] = 0;location[2] = 0;location[3] = 0;location[4] = 0;location[5] = 0;location[6] = 0;location[7] = 0; 
      on = 0;
    end
    else begin
      // bit 1의 bit location들을 찾자
      iter = 0;
      on = 0;
      for (j=0; j<`PPB; j=j+1) begin
        if (eq[j] == 1'b1) begin
          location[iter] = j;
          on[iter] = 1;
          iter = iter+1;
        end
      end
    end
  end
  
  assign o1 = location[0];
  assign o2 = location[1];
  assign o3 = location[2];
  assign o4 = location[3];
  assign o5 = location[4];
  assign o6 = location[5];
  assign o7 = location[6];
  assign o8 = location[7];
  assign switch_on = on;
      
  assign eq_list = eq;
  
endmodule




module top(out, num_tpn, clk, rst, b_idx, a, x1, x2, x3, x4, put_global_array, num_real_patterns);
  input clk, rst;
  input [`B_SIZE-1:0] a; // input vector
  input [`P_SIZE-1:0] x1, x2, x3, x4; // 4 patterns to compare
  input [`NOB_WIDTH:0] b_idx; // block index
  input put_global_array;
  input [`NUM_PATT_WIDTH-1:0] num_real_patterns;
  
  output reg [`MAX_TPN_NUM*`NOP_WIDTH-1:0] out;
  output reg [`MAX_TPN_NUM_WIDTH-1:0] num_tpn;
  
  reg [`NUM_PATT_WIDTH-1:0] k;
  always @ (posedge clk, negedge rst) begin
    if (!rst) begin k <= 0; end
    else begin 
      case (num_real_patterns) 
        3'd1: k <= 3'b000;
        3'd2: k <= 3'b001;
        3'd3: k <= 3'b011;
        3'd4: k <= 3'b111;
      endcase
    end
  end
  
  wire [`PPB-1:0] eq_list;
  wire [`PPB_WIDTH-1:0] out1, out2, out3, out4, out5, out6, out7, out8;
  wire [`MAX_TPN_NUM-1:0] out_on;
  
  /* Pattern Check in 1 epoch(block) */
  comparator_block b0(eq_list, clk, rst, a, b_idx, k, x1, x2, x3, x4, out1, out2, out3, out4, out5, out6, out7, out8, out_on);
  
  always @ (posedge put_global_array, negedge rst) begin
    if (!rst) begin out = 0; num_tpn = 0; end
    else begin
      if (out_on == 8'b00000001) begin
        out[num_tpn*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out1; 
        num_tpn = num_tpn+1; 
      end
      else if (out_on == 8'b00000011) begin
        out[num_tpn*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out1; 
        out[(num_tpn+1)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out2; 
        num_tpn = num_tpn+2; 
      end
      else if (out_on == 8'b00000111) begin
        out[num_tpn*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out1; 
        out[(num_tpn+1)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out2; 
        out[(num_tpn+2)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out3; 
        num_tpn = num_tpn+3; 
      end
      else if (out_on == 8'b00001111) begin
        out[num_tpn*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out1; 
        out[(num_tpn+1)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out2; 
        out[(num_tpn+2)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out3; 
        out[(num_tpn+3)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out4; 
        num_tpn = num_tpn+4; 
      end
      else if (out_on == 8'b00011111) begin
        out[num_tpn*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out1; 
        out[(num_tpn+1)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out2; 
        out[(num_tpn+2)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out3; 
        out[(num_tpn+3)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out4; 
        out[(num_tpn+4)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out5; 
        num_tpn = num_tpn+5; 
      end
      else if (out_on == 8'b00111111) begin
        out[num_tpn*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out1; 
        out[(num_tpn+1)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out2; 
        out[(num_tpn+2)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out3; 
        out[(num_tpn+3)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out4; 
        out[(num_tpn+4)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out5; 
        out[(num_tpn+5)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out6; 
        num_tpn = num_tpn+6; 
      end
      else if (out_on == 8'b01111111) begin
        out[num_tpn*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out1; 
        out[(num_tpn+1)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out2; 
        out[(num_tpn+2)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out3; 
        out[(num_tpn+3)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out4; 
        out[(num_tpn+4)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out5; 
        out[(num_tpn+5)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out6; 
        out[(num_tpn+6)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out7; 
        num_tpn = num_tpn+7; 
      end
      else if (out_on == 8'b11111111) begin
        out[num_tpn*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out1; 
        out[(num_tpn+1)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out2; 
        out[(num_tpn+2)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out3; 
        out[(num_tpn+3)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out4; 
        out[(num_tpn+4)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out5; 
        out[(num_tpn+5)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out6; 
        out[(num_tpn+6)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out7; 
        out[(num_tpn+7)*`NOP_WIDTH +: `NOP_WIDTH] = (b_idx-1)*`PPB + out8; 
        num_tpn = num_tpn+8; 
      end
    end
  end
 
  
  /* Check whether the output is correct. It is not necessary in actual work. */
  /* For real workload, ret0~7 are enough */
  wire [`NOP_WIDTH-1:0] ret0, ret1, ret2, ret3, ret4, ret5, ret6, ret7;
  assign ret0[`NOP_WIDTH-1:0] = out[`NOP_WIDTH*1-1:`NOP_WIDTH*0];
  assign ret1[`NOP_WIDTH-1:0] = out[`NOP_WIDTH*2-1:`NOP_WIDTH*1];
  assign ret2[`NOP_WIDTH-1:0] = out[`NOP_WIDTH*3-1:`NOP_WIDTH*2];
  assign ret3[`NOP_WIDTH-1:0] = out[`NOP_WIDTH*4-1:`NOP_WIDTH*3];
  assign ret4[`NOP_WIDTH-1:0] = out[`NOP_WIDTH*5-1:`NOP_WIDTH*4];
  assign ret5[`NOP_WIDTH-1:0] = out[`NOP_WIDTH*6-1:`NOP_WIDTH*5];
  assign ret6[`NOP_WIDTH-1:0] = out[`NOP_WIDTH*7-1:`NOP_WIDTH*6];
  assign ret7[`NOP_WIDTH-1:0] = out[`NOP_WIDTH*8-1:`NOP_WIDTH*7];
endmodule
