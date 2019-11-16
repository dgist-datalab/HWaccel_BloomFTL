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
  input [2:0] k; // number of real patterns
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
/*
`define CMP_PAGE(modN,eqN,N) \
  comparator_page modN(eqN, a_part[`P_SIZE*(N+1)-1:`P_SIZE*N], k, x1, x2, x3, x4)

`define COMPUTE_TPN(eqN, N) \
  if (eqN) begin \
    global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+N; \
    for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end \
      tpn_ofs = tpn_ofs+`NOP_WIDTH; \
    end
    */

module comparator_block(tpn_arr, tpn_ofs, clk, rst, a_part, b_idx, k, x1, x2, x3, x4);
  input [`B_SIZE-1:0] a_part;
  input [`P_SIZE-1:0] x1, x2, x3, x4;
  input [`NOB_WIDTH:0] b_idx;
  input clk, rst;
  input [2:0] k;
  
  output reg [`NOP_WIDTH*`PPB - 1 : 0] tpn_arr; // array of true page numbers in this block
  output reg [`B_OFS_WIDTH-1:0] tpn_ofs; // bit index(block offset) of true pages in this block // 0~40
  
  wire eq0, eq1, eq2, eq3, eq4, eq5, eq6, eq7, eq8, eq9; 
  wire eq10, eq11, eq12, eq13, eq14, eq15, eq16, eq17, eq18, eq19;
  wire eq20, eq21, eq22, eq23, eq24, eq25, eq26, eq27, eq28, eq29;
  wire eq30, eq31, eq32, eq33, eq34, eq35, eq36, eq37, eq38, eq39;
  wire eq40, eq41, eq42, eq43, eq44, eq45, eq46, eq47, eq48, eq49;
  wire eq50, eq51, eq52, eq53, eq54, eq55, eq56, eq57, eq58, eq59;
  wire eq60, eq61, eq62, eq63;
  
  /* Compare each pages with 4 patterns */
  comparator_page p0(eq0, a_part[`P_SIZE*(0+1)-1:`P_SIZE*0], k, x1, x2, x3, x4)
  comparator_page p1(eq1, a_part[`P_SIZE*(1+1)-1:`P_SIZE*1], k, x1, x2, x3, x4)
  comparator_page p2(eq2, a_part[`P_SIZE*(2+1)-1:`P_SIZE*2], k, x1, x2, x3, x4)
  comparator_page p3(eq3, a_part[`P_SIZE*(3+1)-1:`P_SIZE*3], k, x1, x2, x3, x4)
  comparator_page p4(eq4, a_part[`P_SIZE*(4+1)-1:`P_SIZE*4], k, x1, x2, x3, x4)
  comparator_page p5(eq5, a_part[`P_SIZE*(5+1)-1:`P_SIZE*5], k, x1, x2, x3, x4)
  comparator_page p6(eq6, a_part[`P_SIZE*(6+1)-1:`P_SIZE*6], k, x1, x2, x3, x4)
  comparator_page p7(eq7, a_part[`P_SIZE*(7+1)-1:`P_SIZE*7], k, x1, x2, x3, x4)
  comparator_page p8(eq8, a_part[`P_SIZE*(8+1)-1:`P_SIZE*8], k, x1, x2, x3, x4)
  comparator_page p9(eq9, a_part[`P_SIZE*(9+1)-1:`P_SIZE*9], k, x1, x2, x3, x4)
  comparator_page p10(eq10, a_part[`P_SIZE*(10+1)-1:`P_SIZE*10], k, x1, x2, x3, x4)
  comparator_page p11(eq11, a_part[`P_SIZE*(11+1)-1:`P_SIZE*11], k, x1, x2, x3, x4)
  comparator_page p12(eq12, a_part[`P_SIZE*(12+1)-1:`P_SIZE*12], k, x1, x2, x3, x4)
  comparator_page p13(eq13, a_part[`P_SIZE*(13+1)-1:`P_SIZE*13], k, x1, x2, x3, x4)
  comparator_page p14(eq14, a_part[`P_SIZE*(14+1)-1:`P_SIZE*14], k, x1, x2, x3, x4)
  comparator_page p15(eq15, a_part[`P_SIZE*(15+1)-1:`P_SIZE*15], k, x1, x2, x3, x4)
  comparator_page p16(eq16, a_part[`P_SIZE*(16+1)-1:`P_SIZE*16], k, x1, x2, x3, x4)
  comparator_page p17(eq17, a_part[`P_SIZE*(17+1)-1:`P_SIZE*17], k, x1, x2, x3, x4)
  comparator_page p18(eq18, a_part[`P_SIZE*(18+1)-1:`P_SIZE*18], k, x1, x2, x3, x4)
  comparator_page p19(eq19, a_part[`P_SIZE*(19+1)-1:`P_SIZE*19], k, x1, x2, x3, x4)
  comparator_page p20(eq20, a_part[`P_SIZE*(20+1)-1:`P_SIZE*20], k, x1, x2, x3, x4)
  comparator_page p21(eq21, a_part[`P_SIZE*(21+1)-1:`P_SIZE*21], k, x1, x2, x3, x4)
  comparator_page p22(eq22, a_part[`P_SIZE*(22+1)-1:`P_SIZE*22], k, x1, x2, x3, x4)
  comparator_page p23(eq23, a_part[`P_SIZE*(23+1)-1:`P_SIZE*23], k, x1, x2, x3, x4)
  comparator_page p24(eq24, a_part[`P_SIZE*(24+1)-1:`P_SIZE*24], k, x1, x2, x3, x4)
  comparator_page p25(eq25, a_part[`P_SIZE*(25+1)-1:`P_SIZE*25], k, x1, x2, x3, x4)
  comparator_page p26(eq26, a_part[`P_SIZE*(26+1)-1:`P_SIZE*26], k, x1, x2, x3, x4)
  comparator_page p27(eq27, a_part[`P_SIZE*(27+1)-1:`P_SIZE*27], k, x1, x2, x3, x4)
  comparator_page p28(eq28, a_part[`P_SIZE*(28+1)-1:`P_SIZE*28], k, x1, x2, x3, x4)
  comparator_page p29(eq29, a_part[`P_SIZE*(29+1)-1:`P_SIZE*29], k, x1, x2, x3, x4)
  comparator_page p30(eq30, a_part[`P_SIZE*(30+1)-1:`P_SIZE*20], k, x1, x2, x3, x4)
  comparator_page p31(eq31, a_part[`P_SIZE*(31+1)-1:`P_SIZE*31], k, x1, x2, x3, x4)
  comparator_page p32(eq32, a_part[`P_SIZE*(32+1)-1:`P_SIZE*32], k, x1, x2, x3, x4)
  comparator_page p33(eq33, a_part[`P_SIZE*(33+1)-1:`P_SIZE*33], k, x1, x2, x3, x4)
  comparator_page p34(eq34, a_part[`P_SIZE*(34+1)-1:`P_SIZE*34], k, x1, x2, x3, x4)
  comparator_page p35(eq35, a_part[`P_SIZE*(35+1)-1:`P_SIZE*35], k, x1, x2, x3, x4)
  comparator_page p36(eq36, a_part[`P_SIZE*(36+1)-1:`P_SIZE*36], k, x1, x2, x3, x4)
  comparator_page p37(eq37, a_part[`P_SIZE*(37+1)-1:`P_SIZE*37], k, x1, x2, x3, x4)
  comparator_page p38(eq38, a_part[`P_SIZE*(38+1)-1:`P_SIZE*38], k, x1, x2, x3, x4)
  comparator_page p39(eq39, a_part[`P_SIZE*(39+1)-1:`P_SIZE*39], k, x1, x2, x3, x4)
  comparator_page p40(eq40, a_part[`P_SIZE*(40+1)-1:`P_SIZE*30], k, x1, x2, x3, x4)
  comparator_page p41(eq41, a_part[`P_SIZE*(41+1)-1:`P_SIZE*41], k, x1, x2, x3, x4)
  comparator_page p42(eq42, a_part[`P_SIZE*(42+1)-1:`P_SIZE*42], k, x1, x2, x3, x4)
  comparator_page p43(eq43, a_part[`P_SIZE*(43+1)-1:`P_SIZE*43], k, x1, x2, x3, x4)
  comparator_page p44(eq44, a_part[`P_SIZE*(44+1)-1:`P_SIZE*44], k, x1, x2, x3, x4)
  comparator_page p45(eq45, a_part[`P_SIZE*(45+1)-1:`P_SIZE*45], k, x1, x2, x3, x4)
  comparator_page p46(eq46, a_part[`P_SIZE*(46+1)-1:`P_SIZE*46], k, x1, x2, x3, x4)
  comparator_page p47(eq47, a_part[`P_SIZE*(47+1)-1:`P_SIZE*47], k, x1, x2, x3, x4)
  comparator_page p48(eq48, a_part[`P_SIZE*(48+1)-1:`P_SIZE*48], k, x1, x2, x3, x4)
  comparator_page p49(eq49, a_part[`P_SIZE*(49+1)-1:`P_SIZE*49], k, x1, x2, x3, x4)
  comparator_page p50(eq50, a_part[`P_SIZE*(50+1)-1:`P_SIZE*50], k, x1, x2, x3, x4)
  comparator_page p51(eq51, a_part[`P_SIZE*(51+1)-1:`P_SIZE*51], k, x1, x2, x3, x4)
  comparator_page p52(eq52, a_part[`P_SIZE*(52+1)-1:`P_SIZE*52], k, x1, x2, x3, x4)
  comparator_page p53(eq53, a_part[`P_SIZE*(53+1)-1:`P_SIZE*53], k, x1, x2, x3, x4)
  comparator_page p54(eq54, a_part[`P_SIZE*(54+1)-1:`P_SIZE*54], k, x1, x2, x3, x4)
  comparator_page p55(eq55, a_part[`P_SIZE*(55+1)-1:`P_SIZE*55], k, x1, x2, x3, x4)
  comparator_page p56(eq56, a_part[`P_SIZE*(56+1)-1:`P_SIZE*56], k, x1, x2, x3, x4)
  comparator_page p57(eq57, a_part[`P_SIZE*(57+1)-1:`P_SIZE*57], k, x1, x2, x3, x4)
  comparator_page p58(eq58, a_part[`P_SIZE*(58+1)-1:`P_SIZE*58], k, x1, x2, x3, x4)
  comparator_page p59(eq59, a_part[`P_SIZE*(59+1)-1:`P_SIZE*59], k, x1, x2, x3, x4)
  comparator_page p60(eq60, a_part[`P_SIZE*(60+1)-1:`P_SIZE*60], k, x1, x2, x3, x4)
  comparator_page p61(eq61, a_part[`P_SIZE*(61+1)-1:`P_SIZE*61], k, x1, x2, x3, x4)
  comparator_page p62(eq62, a_part[`P_SIZE*(62+1)-1:`P_SIZE*62], k, x1, x2, x3, x4)
  comparator_page p63(eq63, a_part[`P_SIZE*(63+1)-1:`P_SIZE*63], k, x1, x2, x3, x4)
  /*
  `CMP_PAGE(p0, eq0, 0);
  `CMP_PAGE(p1, eq1, 1);
  `CMP_PAGE(p2, eq2, 2);
  `CMP_PAGE(p3, eq3, 3);
  `CMP_PAGE(p4, eq4, 4);
  `CMP_PAGE(p5, eq5, 5);
  `CMP_PAGE(p6, eq6, 6);
  `CMP_PAGE(p7, eq7, 7);
  `CMP_PAGE(p8, eq8, 8);
  `CMP_PAGE(p9, eq9, 9);
  `CMP_PAGE(p10, eq10, 10);
  `CMP_PAGE(p11, eq11, 11);
  `CMP_PAGE(p12, eq12, 12);
  `CMP_PAGE(p13, eq13, 13);
  `CMP_PAGE(p14, eq14, 14);
  `CMP_PAGE(p15, eq15, 15);
  `CMP_PAGE(p16, eq16, 16);
  `CMP_PAGE(p17, eq17, 17);
  `CMP_PAGE(p18, eq18, 18);
  `CMP_PAGE(p19, eq19, 19);
  `CMP_PAGE(p20, eq20, 20);
  `CMP_PAGE(p21, eq21, 21);
  `CMP_PAGE(p22, eq22, 22);
  `CMP_PAGE(p23, eq23, 23);
  `CMP_PAGE(p24, eq24, 24);
  `CMP_PAGE(p25, eq25, 25);
  `CMP_PAGE(p26, eq26, 26);
  `CMP_PAGE(p27, eq27, 27);
  `CMP_PAGE(p28, eq28, 28);
  `CMP_PAGE(p29, eq29, 29);
  `CMP_PAGE(p30, eq30, 30);
  `CMP_PAGE(p31, eq31, 31);
  `CMP_PAGE(p32, eq32, 32);
  `CMP_PAGE(p33, eq33, 33);
  `CMP_PAGE(p34, eq34, 34);
  `CMP_PAGE(p35, eq35, 35);
  `CMP_PAGE(p36, eq36, 36);
  `CMP_PAGE(p37, eq37, 37);
  `CMP_PAGE(p38, eq38, 38);
  `CMP_PAGE(p39, eq39, 39);
  `CMP_PAGE(p40, eq40, 40);
  `CMP_PAGE(p41, eq41, 41);
  `CMP_PAGE(p42, eq42, 42);
  `CMP_PAGE(p43, eq43, 43);
  `CMP_PAGE(p44, eq44, 44);
  `CMP_PAGE(p45, eq45, 45);
  `CMP_PAGE(p46, eq46, 46);
  `CMP_PAGE(p47, eq47, 47);
  `CMP_PAGE(p48, eq48, 48);
  `CMP_PAGE(p49, eq49, 49);
  `CMP_PAGE(p50, eq50, 50);
  `CMP_PAGE(p51, eq51, 51);
  `CMP_PAGE(p52, eq52, 52);
  `CMP_PAGE(p53, eq53, 53);
  `CMP_PAGE(p54, eq54, 54);
  `CMP_PAGE(p55, eq55, 55);
  `CMP_PAGE(p56, eq56, 56);
  `CMP_PAGE(p57, eq57, 57);
  `CMP_PAGE(p58, eq58, 58);
  `CMP_PAGE(p59, eq59, 59);
  `CMP_PAGE(p60, eq60, 60);
  `CMP_PAGE(p61, eq61, 61);
  `CMP_PAGE(p62, eq62, 62);
  `CMP_PAGE(p63, eq63, 63);
  */
  /*
  comparator_page p0(eq0, a_part[`P_SIZE*1-1:`P_SIZE*0], x1, x2, x3, x4);
  comparator_page p1(eq1, a_part[`P_SIZE*2-1:`P_SIZE*1], x1, x2, x3, x4);
  */
  
  reg [`NOP_WIDTH-1:0] global_tpn;
  integer i; 
  
  /*
`define COMPUTE_TPN(eqN, N) \
  if (eqN) begin \
    global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+N; \
    for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end \
      tpn_ofs = tpn_ofs+`NOP_WIDTH; \
    end
    */
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
      if (eq8) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+8;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq9) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+9;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq10) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+10;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq11) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+11;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq12) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+12;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq13) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+13;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq14) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+14;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq15) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+15;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq16) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+16;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq17) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+17;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq18) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+18;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq19) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+19;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq20) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+20;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq21) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+21;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq22) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+22;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq23) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+23;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq24) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+24;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq25) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+25;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq26) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+26;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq27) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+27;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq28) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+28;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq29) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+29;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq30) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+30;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq31) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+31;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq32) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+32;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq33) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+33;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq34) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+34;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq35) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+35;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq36) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+36;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq37) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+37;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq38) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+38;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq39) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+39;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq40) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+40;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq41) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+41;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq42) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+42;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq43) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+43;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq44) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+44;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq45) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+45;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq46) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+46;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq47) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+47;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq48) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+48;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq49) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+49;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq50) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+50;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq51) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+51;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq52) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+52;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq53) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+53;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq54) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+54;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq55) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+55;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq56) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+56;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq57) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+57;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq58) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+58;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq59) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+59;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq60) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+60;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq61) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+61;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq62) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+62;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      if (eq63) begin
        global_tpn[`NOP_WIDTH-1:0] = b_idx*`PPB+63;
        for (i=0; i<`NOP_WIDTH; i=i+1) begin tpn_arr[tpn_ofs+i] = global_tpn[i]; end
        tpn_ofs = tpn_ofs+`NOP_WIDTH;
      end
      /*
      `COMPUTE_TPN(eq0, 0)
      `COMPUTE_TPN(eq1, 1)
      `COMPUTE_TPN(eq2, 2)
      `COMPUTE_TPN(eq3, 3)
      `COMPUTE_TPN(eq4, 4)
      `COMPUTE_TPN(eq5, 5)
      `COMPUTE_TPN(eq6, 6)
      `COMPUTE_TPN(eq7, 7)
      `COMPUTE_TPN(eq8, 8)
      `COMPUTE_TPN(eq9, 9)
      `COMPUTE_TPN(eq10, 10)
      `COMPUTE_TPN(eq11, 11)
      `COMPUTE_TPN(eq12, 12)
      `COMPUTE_TPN(eq13, 13)
      `COMPUTE_TPN(eq14, 14)
      `COMPUTE_TPN(eq15, 15)
      `COMPUTE_TPN(eq16, 16)
      `COMPUTE_TPN(eq17, 17)
      `COMPUTE_TPN(eq18, 18)
      `COMPUTE_TPN(eq19, 19)
      `COMPUTE_TPN(eq20, 20)
      `COMPUTE_TPN(eq21, 21)
      `COMPUTE_TPN(eq22, 22)
      `COMPUTE_TPN(eq23, 23)
      `COMPUTE_TPN(eq24, 24)
      `COMPUTE_TPN(eq25, 25)
      `COMPUTE_TPN(eq26, 26)
      `COMPUTE_TPN(eq27, 27)
      `COMPUTE_TPN(eq28, 28)
      `COMPUTE_TPN(eq29, 29)
      `COMPUTE_TPN(eq30, 30)
      `COMPUTE_TPN(eq31, 31)
      `COMPUTE_TPN(eq32, 32)
      `COMPUTE_TPN(eq33, 33)
      `COMPUTE_TPN(eq34, 34)
      `COMPUTE_TPN(eq35, 35)
      `COMPUTE_TPN(eq36, 36)
      `COMPUTE_TPN(eq37, 37)
      `COMPUTE_TPN(eq38, 38)
      `COMPUTE_TPN(eq39, 39)
      `COMPUTE_TPN(eq40, 40)
      `COMPUTE_TPN(eq41, 41)
      `COMPUTE_TPN(eq42, 42)
      `COMPUTE_TPN(eq43, 43)
      `COMPUTE_TPN(eq44, 44)
      `COMPUTE_TPN(eq45, 45)
      `COMPUTE_TPN(eq46, 46)
      `COMPUTE_TPN(eq47, 47)
      `COMPUTE_TPN(eq48, 48)
      `COMPUTE_TPN(eq49, 49)
      `COMPUTE_TPN(eq50, 50)
      `COMPUTE_TPN(eq51, 51)
      `COMPUTE_TPN(eq52, 52)
      `COMPUTE_TPN(eq53, 53)
      `COMPUTE_TPN(eq54, 54)
      `COMPUTE_TPN(eq55, 55)
      `COMPUTE_TPN(eq56, 56)
      `COMPUTE_TPN(eq57, 57)
      `COMPUTE_TPN(eq58, 58)
      `COMPUTE_TPN(eq59, 59)
      `COMPUTE_TPN(eq60, 60)
      `COMPUTE_TPN(eq61, 61)
      `COMPUTE_TPN(eq62, 62)
      `COMPUTE_TPN(eq63, 63)
      */
      /*
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
      */
    end
  end
  
endmodule
  
`define ASSIGN_INPUT(B_IDX) a_part[`B_SIZE-1:0] <= a[`B_SIZE*(B_IDX+1)-1 : `B_SIZE*B_IDX]

module find_bit_pattern(g_tpn_arr, clk, rst, b_idx, a, x1, x2, x3, x4, put_global_array, num_real_patterns);
  input clk, rst;
  input [`B_SIZE-1:0] a; // input vector
  input [`P_SIZE-1:0] x1, x2, x3, x4; // 4 patterns to compare
  input [`NOB_WIDTH:0] b_idx; // block index
  input put_global_array;
  input [2:0] num_real_patterns;
  
  output reg [`NOP_WIDTH*`NOP-1:0] g_tpn_arr; // global(main) array of true page numbers(indices)
  
  //reg [`B_SIZE-1:0] a_part; // block-unit part of input vector
  
  /*
  always @ (posedge clk, negedge rst) begin
    if (!rst) begin a_part <= 0; end
    else begin 
      a_part[`B_SIZE-1:0] <= a[`B_SIZE-1:0];
    end
  end
  */
  
  reg [2:0] k;
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
  
  wire [`NOP_WIDTH*`PPB-1 : 0] out_tpn_arr; // array of true page numbers in this block
  wire [`B_OFS_WIDTH-1:0] out_tpn_ofs; // bit index(block offset) of true pages in one block // 0~40
  
  /* Pattern Check in 1 epoch(block) */
  comparator_block b0(out_tpn_arr, out_tpn_ofs, clk, rst, a, b_idx, k, x1, x2, x3, x4);
  
  reg [`NOP_WIDTH*`NOP-1:0] g_tpn_ofs; // bit index(offset) of global tpn array
 
  /* FIFO buffer: insert the output of comparator_block(out_tpn_arr) into g_tpn_arr. g_tpn_arr will have the numbers(indices) of all true pages */
  integer i;
  always @ (posedge put_global_array, negedge rst) begin
    if (!rst)  begin g_tpn_arr = 0; g_tpn_ofs = 0; end
    else begin
      /*
       * 지금은 page가 총 24개여서 page index가 5-bit(NOP_WIDTH)로 표현되므로 5-bit 단위(5의 배수)로 끊지만, 6144-bit라면 page index가 0~511이므로 NOP_WIDTH가 9-bit가 된다. 
       * 따라서 그때는 9-bit 단위로 끊기게 하는 게 align에 맞다 (이렇게 안해도 상관없지만 의미없는 연산이 추가됨)
       * 실제로는 true page 수가 매우 적으며, 현재 C code 세팅은 1개 아니면 2개이다. (false positive parameter를 어떻게 정하느냐에 따라 1개~n개가 되는데, 지금은 n=2인 셈이다)
       * 즉, 한 epoch(block)에서는 대부분 0개에 가끔 1개, 매우 드물게 2개까지 나오는 셈
       */
      
      /* 4096 page, PPB 32, NOB 128 기준으로는, B_OFS_WIDTH가 9이며 NOP_WIDTH가 12이므로 12의 배수로 끊는다. */
      /* 4096 page, PPB 64, NOB 64 기준으로는 B_OFS_WIDTH가 10이며 NOP_WIDTH가 12이므로 12의 배수로 끊는다. */
      if (out_tpn_ofs != 0) begin
        if (out_tpn_ofs <= `B_OFS_WIDTH'd12) begin 
          for (i=0; i<12; i=i+1) begin g_tpn_arr[g_tpn_ofs+i] = out_tpn_arr[i]; end
          g_tpn_ofs = g_tpn_ofs + out_tpn_ofs;
        end
        else if (out_tpn_ofs <= `B_OFS_WIDTH'd24) begin
          for (i=0; i<24; i=i+1) begin g_tpn_arr[g_tpn_ofs+i] = out_tpn_arr[i]; end
          g_tpn_ofs = g_tpn_ofs + out_tpn_ofs;
        end
        
        /* 실제 test case에서는 최대 true page 개수가 2개이므로 이 이후는 사실상 수행되지 않는다 */
        else if (out_tpn_ofs <= `B_OFS_WIDTH'd36) begin
          for (i=0; i<36; i=i+1) begin g_tpn_arr[g_tpn_ofs+i] = out_tpn_arr[i]; end
          g_tpn_ofs = g_tpn_ofs + out_tpn_ofs;
        end
        else if (out_tpn_ofs <= `B_OFS_WIDTH'd768) begin
          for (i=0; i<768; i=i+1) begin g_tpn_arr[g_tpn_ofs+i] = out_tpn_arr[i]; end
          g_tpn_ofs = g_tpn_ofs + out_tpn_ofs;
        end
      end
    end
  end
  
  /* Check whether the output is correct. It is not necessary in actual work. */
  /* For real workload, ret0 and ret1 are enough */
  wire [`NOP_WIDTH-1:0] ret0, ret1, ret2, ret3, ret4, ret5, ret6, ret7, ret8, ret9, ret10, ret11;
  wire [`NOP_WIDTH-1:0] ret12, ret13, ret14, ret15, ret16, ret17, ret18, ret19, ret20, ret21, ret22, ret23;
  assign ret0[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*1-1:`NOP_WIDTH*0];
  assign ret1[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*2-1:`NOP_WIDTH*1];
  assign ret2[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*3-1:`NOP_WIDTH*2];
  assign ret3[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*4-1:`NOP_WIDTH*3];
  assign ret4[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*5-1:`NOP_WIDTH*4];
  assign ret5[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*6-1:`NOP_WIDTH*5];
  assign ret6[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*7-1:`NOP_WIDTH*6];
  assign ret7[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*8-1:`NOP_WIDTH*7];
  assign ret8[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*9-1:`NOP_WIDTH*8];
  assign ret9[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*10-1:`NOP_WIDTH*9];
  assign ret10[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*11-1:`NOP_WIDTH*10];
  assign ret11[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*12-1:`NOP_WIDTH*11];
  assign ret12[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*13-1:`NOP_WIDTH*12];
  assign ret13[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*14-1:`NOP_WIDTH*13];
  assign ret14[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*15-1:`NOP_WIDTH*14];
  assign ret15[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*16-1:`NOP_WIDTH*15];
  assign ret16[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*17-1:`NOP_WIDTH*16];
  assign ret17[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*18-1:`NOP_WIDTH*17];
  assign ret18[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*19-1:`NOP_WIDTH*18];
  assign ret19[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*20-1:`NOP_WIDTH*19];
  assign ret20[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*21-1:`NOP_WIDTH*20];
  assign ret21[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*22-1:`NOP_WIDTH*21];
  assign ret22[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*23-1:`NOP_WIDTH*22];
  assign ret23[`NOP_WIDTH-1:0] = g_tpn_arr[`NOP_WIDTH*24-1:`NOP_WIDTH*23];
endmodule`
