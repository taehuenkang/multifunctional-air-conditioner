`timescale 1ns / 1ps

module top(
    input clk,
    input reset,
    input btnU,
    input btnC,
    input btnL,
    input btnR,
    input btnD,
    input door,
    input RsRx,
    input echo,

    output trig,
    output RsTx,
    output reg buzzer,
    output reg [7:0] seg,
    output reg [3:0] an,
    output [15:0] led,
    output reg [1:0] in1_in2,
    output servo,
    output reg dc_motor,

    inout dht11_data
);

    // UART 명령어 신호
    wire btnU_command, btnC_command, btnL_command, btnR_command, btnD_command, door_command;
    wire reset_command, mod0, mod1, mod2;

    // 버튼 OR UART 명령 신호 결합
    wire s_btnU = btnU | btnU_command;
    wire s_btnC = btnC | btnC_command;
    wire s_btnL = btnL | btnL_command;
    wire s_btnR = btnR | btnR_command;
    wire s_btnD = btnD | btnD_command;
    wire s_door = door | door_command;

    // one-pulse 처리
    wire w_btnR;
    debounce_pushbutton u_btnR(.clk(clk), .noise_btn(s_btnR), .clean_btn(w_btnR));

    // 상태에 따른 세그먼트 출력
    wire [7:0] w_minsec_stop_seg;
    wire [3:0] w_minsec_stop_an;

    wire [7:0] w_microwave_stop_seg;
    wire [3:0] w_microwave_stop_an;
    wire w_microwave_buzzer;
    wire [1:0] w_microwave_in1_in2;
    wire w_microwave_dc_motor;

    wire [7:0] w_air_conditioner_seg;
    wire [3:0] w_air_conditioner_an;
    wire w_air_conditioner_dc_motor;
    wire [1:0] w_air_conditioner_in1_in2;
    wire w_air_conditioner_buzzer;

    parameter minsec_stop = 2'b00,
              microwave   = 2'b01,
              air_conditioner = 2'b10;

    reg [1:0] current_state = minsec_stop; 
    reg [1:0] next_state;

    wire global_reset = reset | reset_command;

    always @ (posedge clk or posedge global_reset) begin
        if(global_reset) current_state <= minsec_stop;
        else             current_state <= next_state;
    end    

    always @(*) begin
        case(current_state)
            minsec_stop:      next_state = (w_btnR || mod1) ? microwave : minsec_stop;
            microwave:        next_state = (w_btnR || mod2) ? air_conditioner : microwave;
            air_conditioner:  next_state = (w_btnR || mod0) ? minsec_stop : air_conditioner;
        endcase
    end

    always @(*) begin
        seg = 8'hff; 
        an = 4'hf;   
        buzzer = 1'b0;
        in1_in2 = 2'b00;
        dc_motor = 1'b0;

        case(current_state)
            minsec_stop: begin
                seg = w_minsec_stop_seg;
                an = w_minsec_stop_an;
                buzzer = 1'b0;
                in1_in2 = 2'b00;
                dc_motor = 1'b0;
            end
            microwave: begin
                seg = w_microwave_stop_seg;
                an = w_microwave_stop_an; 
                buzzer = w_microwave_buzzer; 
                in1_in2 = w_microwave_in1_in2;     
                dc_motor = w_microwave_dc_motor;
            end
            air_conditioner: begin
                seg = w_air_conditioner_seg;
                an = w_air_conditioner_an;
                dc_motor = w_air_conditioner_dc_motor;
                in1_in2 = w_air_conditioner_in1_in2;       
                buzzer = w_air_conditioner_buzzer;        
            end
            default: begin
                // default도 명확하게 할당
                seg = w_minsec_stop_seg;
                an = w_minsec_stop_an;
                buzzer = 1'b0;
                in1_in2 = 2'b00;
                dc_motor = 1'b0;
            end
        endcase
    end   

    minsec_stop_top u_minsec_stop_top(
        .clk(clk),
        .reset(global_reset),         
        .btnU(s_btnU),   
        .btnC(s_btnC),   
        .btnD(s_btnD),   
        .seg(w_minsec_stop_seg),
        .an(w_minsec_stop_an),
        .led(led)
    );

    microwave_top u_microwave_top(
        .clk(clk),
        .reset(global_reset),
        .btnU(s_btnU),
        .btnL(s_btnL),
        .btnC(s_btnC),
        .btnD(s_btnD),
        .door(s_door),
        .seg(w_microwave_stop_seg),
        .an(w_microwave_stop_an),
        .buzzer(w_microwave_buzzer),
        .in1_in2(w_microwave_in1_in2),
        .servo(servo), 
        .dc_motor(w_microwave_dc_motor)
    );

    air_conditioner u_air_conditioner(
        .clk(clk),
        .reset(global_reset),
        .btnU(s_btnU),
        .btnC(s_btnC),
        .btnD(s_btnD),
        .btnL(s_btnL),
        .btnR(s_btnR),
        .RsRx(RsRx),
        .echo(echo),
        .RsTx(RsTx),
        .trig(trig),
        .seg(w_air_conditioner_seg),
        .an(w_air_conditioner_an),
        .dc_motor(w_air_conditioner_dc_motor),
        .in1_in2(w_air_conditioner_in1_in2),       
        .buzzer(w_air_conditioner_buzzer),
        .dht11_data(dht11_data)
    );

    wire [7:0] rx_data;
    wire rx_done;

    uart_command_controller u_uart_command_controller (
        .clk(clk),
        .reset(reset),
        .rx_data(rx_data),
        .rx_done(rx_done),
        .btnU_command(btnU_command),
        .btnC_command(btnC_command),
        .btnL_command(btnL_command),
        .btnR_command(btnR_command),
        .btnD_command(btnD_command),
        .door_command(door_command),
        .reset_command(reset_command),
        .mod0(mod0),
        .mod1(mod1),
        .mod2(mod2)
    );

    wire w_bd_tick;

    baudrate uart_baud(
        .clk(clk),
        .rst(global_reset),
        .baud_tick(w_bd_tick)
    );

    uart_rx uart_rx_inst (
        .clk(clk),
        .rst(global_reset),
        .b_tick(w_bd_tick),
        .rx(RsRx),
        .o_dout(rx_data),
        .o_rx_done(rx_done)
    );


    assign led[2:0] = (current_state == minsec_stop)      ? 3'b001 :
                      (current_state == microwave)        ? 3'b010 :
                      (current_state == air_conditioner)  ? 3'b100 :
                      3'b000;

endmodule




module uart_rx (
    input clk,
    input rst,
    input b_tick, // 오버샘플링 틱 (예: 1비트당 8틱)
    input rx,
    output [7:0] o_dout,
    output o_rx_done
);
    localparam IDLE      = 0, 
               START_BIT = 1, 
               DATA_BITS = 2, 
               STOP_BIT  = 3, 
               DONE      = 4;

    reg [2:0] c_state, n_state;
    reg [3:0] bit_cnt_reg, bit_cnt_next;
    reg [3:0] sample_cnt_reg, sample_cnt_next;

    reg [7:0] dout_reg, dout_next;
    reg rx_done_reg, rx_done_next;

    assign o_dout    = dout_reg;
    assign o_rx_done = rx_done_reg;

    localparam BITS_PER_TICK            = 8;
    localparam START_BIT_SAMPLE_POINT   = BITS_PER_TICK / 2;
    localparam DATA_BIT_SAMPLE_POINT    = BITS_PER_TICK / 2;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state         <= IDLE;
            bit_cnt_reg     <= 0;
            sample_cnt_reg  <= 0;
            dout_reg        <= 0;
            rx_done_reg     <= 0;
        end else begin
            c_state         <= n_state;
            bit_cnt_reg     <= bit_cnt_next;
            sample_cnt_reg  <= sample_cnt_next;
            dout_reg        <= dout_next;
            rx_done_reg     <= rx_done_next;
        end
    end

    always @(*) begin
        n_state          = c_state;
        bit_cnt_next     = bit_cnt_reg;
        sample_cnt_next  = sample_cnt_reg;
        dout_next        = dout_reg;
        rx_done_next     = rx_done_reg;

        case (c_state)
            IDLE: begin
                bit_cnt_next     = 0;
                sample_cnt_next  = 0;
                rx_done_next     = 0;
                if (b_tick && !rx) begin
                    n_state          = START_BIT;
                    sample_cnt_next  = 1;
                end
            end

            START_BIT: begin
                if (b_tick) begin
                    if (sample_cnt_reg == (BITS_PER_TICK - 1)) begin
                        if (rx) n_state = IDLE;
                        else begin
                            n_state         = DATA_BITS;
                            bit_cnt_next    = 0;
                        end
                        sample_cnt_next = 0;
                    end else begin
                        sample_cnt_next = sample_cnt_reg + 1;
                    end
                end
            end

            DATA_BITS: begin
                if (b_tick) begin
                    if (sample_cnt_reg == (DATA_BIT_SAMPLE_POINT - 1)) begin
                        dout_next = {rx, dout_reg[7:1]}; // LSB first
                    end
                    if (sample_cnt_reg == (BITS_PER_TICK - 1)) begin
                        if (bit_cnt_reg == 7) begin
                            n_state      = STOP_BIT;
                            bit_cnt_next = 0;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                        sample_cnt_next = 0;
                    end else begin
                        sample_cnt_next = sample_cnt_reg + 1;
                    end
                end
            end

            STOP_BIT: begin
                if (b_tick) begin
                    if (sample_cnt_reg == (BITS_PER_TICK - 1)) begin
                        if (!rx) n_state = IDLE;
                        else    n_state = DONE;
                        sample_cnt_next = 0;
                    end else begin
                        sample_cnt_next = sample_cnt_reg + 1;
                    end
                end
            end

            DONE: begin
                rx_done_next = 1;
                n_state      = IDLE;
            end

            default: n_state = IDLE;
        endcase
    end
endmodule


module baudrate (
    input  clk,
    input  rst,
    output baud_tick
);
    parameter BAUD               = 9600;
    parameter CLK_FREQ           = 100_000_000;
    parameter OVERSAMPLING_RATE  = 8;
    parameter BAUD_COUNT         = CLK_FREQ / (BAUD * OVERSAMPLING_RATE);

    reg [$clog2(BAUD_COUNT)-1:0] count_reg, count_next;
    reg baud_tick_reg, baud_tick_next;

    assign baud_tick = baud_tick_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            count_reg     <= 0;
            baud_tick_reg <= 0;
        end else begin
            count_reg     <= count_next;
            baud_tick_reg <= baud_tick_next;
        end
    end

    always @(*) begin
        count_next     = count_reg;
        baud_tick_next = 0;

        if (count_reg == BAUD_COUNT - 1) begin
            count_next     = 0;
            baud_tick_next = 1;
        end else begin
            count_next = count_reg + 1;
        end
    end
endmodule
