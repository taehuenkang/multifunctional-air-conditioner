`timescale 1ns / 1ps

//-------------------  DFF -----------------------
// Debouncing DFFs for push buttons on FPGA
// 4Hz ���ļ��� 1�ֱⰡ 250ms 100MHz/4 --> 25,000,000cycle�� count�ϸ� 
// w_clk4hz_enable�� 1�� set�Ǿ� en�� 1�� mapping �ȴ�. 
module microwave_dff (
    input clk,
    input en,
    input D,
    output reg Q
);  

  always @(posedge clk)
  begin 
  if (en == 1) // slow clock enable signal 
    Q <= D;
  end 
endmodule