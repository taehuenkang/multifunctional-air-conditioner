`timescale 1ns / 1ps

//------------------------------------------------------------------
// buzzer_controller (Refactored v3 - Power-On State Merged)
//------------------------------------------------------------------
module microwave_buzzer_controller (
    input           clk,
    input           reset,
    input           btnU,
    input           btnL,
    input           btnC,
    input           btnD,
    input           door,
    input   [2:0]   mode,
    output  reg     buzzer
);

    // FSM ���� ����
    localparam S_IDLE         = 4'b0000; // ��� ����
    localparam S_CLICK        = 4'b0001; // ��ư Ŭ��/�� ������ ���
    localparam S_POWER_PLAY   = 4'b0010; // [����] �Ŀ��� �Ҹ� ��� (����)
    localparam S_FINISH_BEEP  = 4'b0110; // ���� �˸���
    localparam S_FINISH_PAUSE = 4'b0111; // ���� �˸��� ����

    // �ý��� ��� �Ķ����
    localparam M_IDLE   = 3'b000;
    localparam M_FINISH = 3'b100;

    // �Ҹ� ����(Duration) �Ķ���� (100MHz Ŭ�� ����)
    localparam DUR_20MS   = 28'd2_000_000;   // 20ms
    localparam DUR_70MS   = 28'd7_000_000;   // 70ms
    localparam DUR_100MS  = 28'd10_000_000;  // 100ms
    localparam DUR_1S     = 28'd100_000_000; // 1s

    // ���ļ� ����(Divider) �� �Ķ����
    localparam DIV_CLICK        = 22'd38222;  // �� 1.3kHz
    localparam DIV_FINISH       = 22'd25000;  // 2kHz
    localparam DIV_POWER_1KHZ   = 22'd50000;
    localparam DIV_POWER_2KHZ   = 22'd25000;
    localparam DIV_POWER_3KHZ   = 22'd16667;
    localparam DIV_POWER_4KHZ   = 22'd12500;

    // FSM ��������
    reg [3:0] current_state, next_state;
    reg [1:0] power_on_stage; // [�߰�] �Ŀ��� ���� �ܰ� ī����

    // Ÿ�̸� �� ���ļ� ������
    reg [27:0]  duration_timer;
    reg         duration_timer_start;
    wire        duration_timer_done;
    reg [21:0]  frequency_divider_val;
    reg [21:0]  frequency_counter;
    reg         buzzer_internal;

    // ��ȣ ���� ����
    wire any_button_pressed = btnU | btnL | btnC | btnD;
    reg  door_prev;
    wire door_opened = door && !door_prev;
    wire door_closed = !door && door_prev;

    //================================================
    // 1. Next-State Logic (���� ȸ��)
    //================================================
    always @(*) begin
        // �⺻�� ����
        next_state = current_state;
        duration_timer_start = 1'b0;
        frequency_divider_val = 0;

        if (mode == M_FINISH) begin
            // FINISH ��� ���� (������ ����)
            case(current_state)
                S_FINISH_BEEP: begin
                    frequency_divider_val = DIV_FINISH;
                    if (duration_timer_done) begin
                        next_state = S_FINISH_PAUSE;
                        duration_timer_start = 1'b1;
                    end
                end
                S_FINISH_PAUSE: begin
                    if (duration_timer_done) begin
                        next_state = S_FINISH_BEEP;
                        duration_timer_start = 1'b1;
                    end
                end
                default: begin
                    next_state = S_FINISH_BEEP;
                    duration_timer_start = 1'b1;
                end
            endcase
        end else begin // FINISH ��尡 �ƴ� ���� ����
            case (current_state)
                S_IDLE: begin
                    if (btnC && (mode == M_IDLE)) begin
                        next_state = S_POWER_PLAY; // [����] �Ŀ��� ���� ���·� ��ȯ
                        duration_timer_start = 1'b1;
                    end
                    else if (any_button_pressed || door_opened || door_closed) begin
                        next_state = S_CLICK;
                        duration_timer_start = 1'b1;
                    end
                end
                S_CLICK: begin
                    frequency_divider_val = DIV_CLICK;
                    if (duration_timer_done) begin
                        next_state = S_IDLE;
                    end
                end
                // [����] S_POWER_PLAY ���� ����
                S_POWER_PLAY: begin
                    // ���� stage�� ���� ���ļ� ����
                    case(power_on_stage)
                        2'd0: frequency_divider_val = DIV_POWER_1KHZ;
                        2'd1: frequency_divider_val = DIV_POWER_2KHZ;
                        2'd2: frequency_divider_val = DIV_POWER_3KHZ;
                        2'd3: frequency_divider_val = DIV_POWER_4KHZ;
                        default: frequency_divider_val = 0;
                    endcase

                    // 70ms Ÿ�̸Ӱ� ������
                    if (duration_timer_done) begin
                        // ������ stage������ IDLE�� ����
                        if (power_on_stage == 2'd3) begin
                            next_state = S_IDLE;
                        end
                        // ���� ���� stage�� ��������
                        else begin
                            next_state = S_POWER_PLAY; // ���� ����
                            duration_timer_start = 1'b1; // Ÿ�̸� �����
                        end
                    end
                end
                default: begin
                    next_state = S_IDLE;
                end
            endcase
        end
    end

    //================================================
    // 2. State Register & Edge Detection (���� ȸ��)
    //================================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= S_IDLE;
            door_prev     <= 0;
        end else begin
            current_state <= next_state;
            door_prev     <= door;
        end
    end

    // [�߰�] Power-on Stage ī���� ���� (���� ȸ��)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            power_on_stage <= 0;
        end else begin
            // S_POWER_PLAY ���·� ó�� ������ �� stage�� 0���� �ʱ�ȭ
            if (current_state != S_POWER_PLAY && next_state == S_POWER_PLAY) begin
                power_on_stage <= 0;
            end
            // S_POWER_PLAY ���¸� �����ϸ鼭 Ÿ�̸Ӱ� �Ϸ�Ǹ� stage�� 1 ����
            else if (current_state == S_POWER_PLAY && duration_timer_done) begin
                if (power_on_stage < 2'd3) begin
                    power_on_stage <= power_on_stage + 1;
                end
            end
        end
    end

    //================================================
    // 3. �Ҹ� ���� ���� Ÿ�̸� (���� ȸ��)
    //================================================
    assign duration_timer_done = (duration_timer == 1);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            duration_timer <= 0;
        end else begin
            if (duration_timer_start) begin
                // [����] S_POWER_PLAY�� ���� Ÿ�̸� �� ����
                case(next_state)
                    S_CLICK:        duration_timer <= DUR_20MS;
                    S_POWER_PLAY:   duration_timer <= DUR_70MS;
                    S_FINISH_BEEP:  duration_timer <= DUR_100MS;
                    S_FINISH_PAUSE: duration_timer <= DUR_1S;
                    default:        duration_timer <= 0;
                endcase
            end else if (duration_timer > 0) begin
                duration_timer <= duration_timer - 1;
            end else begin
                duration_timer <= 0;
            end
        end
    end

    //================================================
    // 4. ���ļ�(��) ������ �� ��� ���� (���� ȸ��)
    //================================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            frequency_counter <= 0;
            buzzer_internal   <= 0;
            buzzer            <= 0;
        end else begin
            if (current_state == S_IDLE || current_state == S_FINISH_PAUSE) begin
                frequency_counter <= 0;
                buzzer_internal   <= 0;
            end else begin
                if (frequency_counter >= frequency_divider_val - 1) begin
                    frequency_counter <= 0;
                    buzzer_internal   <= ~buzzer_internal;
                end else begin
                    frequency_counter <= frequency_counter + 1;
                end
            end
            buzzer <= buzzer_internal;
        end
    end

endmodule