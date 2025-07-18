`timescale 1ns / 1ps

module buzzer_controller (
    input clk,
    input reset,

    input pulse_U,
    input pulse_D,
    input pulse_L,
    input pulse_run, //button_c

    input [9:0] distance,

    output wire buzzer
);

    // 1ms ƽ ������
    reg [16:0] ms_count;
    reg tick_1ms;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ms_count <= 0;
            tick_1ms <= 0;
        end else begin
            if (ms_count >= 99999) begin // 100MHz / 1kHz
                ms_count <= 0;
                tick_1ms <= 1;
            end else begin
                ms_count <= ms_count + 1;
                tick_1ms <= 0;
            end
        end
    end

    // --- beep ���� (pulse_U, D, L, R) ---
    reg beep_active;
    reg [1:0] beep_step;    // ���� �Ҹ��� �ܰ� -> 3step�� ����
    reg [11:0] beep_cnt;    // ���� �ܰ��� ����ð�(ms)
    reg [11:0] beep_target; // �� �ܰ��� ���ӽð�(�⺻:100ms)

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            beep_active <= 0;
            beep_step <= 0;
            beep_cnt <= 0;
            beep_target <= 100;
        end else if ((pulse_U || pulse_D || pulse_L) && !beep_active) begin
            beep_active <= 1;
            beep_step <= 0;
            beep_cnt <= 0;
            beep_target <= 100;
        end else if (beep_active) begin
            if (tick_1ms) begin
                if (beep_cnt >= beep_target - 1) begin
                    beep_cnt <= 0;
                    beep_step <= beep_step + 1;
                    beep_target <= 100; // 100ms ����
                    if (beep_step == 3) begin
                        beep_active <= 0;
                    end
                end else begin
                    beep_cnt <= beep_cnt + 1;
                end
            end
        end
    end

    wire [17:0] beep_div_val = (beep_step == 0) ? 18'd50000 :  // 1kHz (��)
                              (beep_step == 1) ? 18'd25000 :  // 2kHz (��)
                              (beep_step == 2) ? 18'd16667 :  // 3kHz (��)
                                                    18'd0;

    reg [17:0] beep_div_cnt;    //���� �ֱ��� ī����
    reg beep_buz;   //���� ���� ��½�ȣ(PWM)
    
    //beep_active ���¿��� beep_div_val�ֱ⸶�� beep_buz ���-> �簢�� ����
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            beep_div_cnt <= 0;
            beep_buz <= 0;
        end else if (beep_active && beep_div_val != 0) begin
            if (beep_div_cnt >= beep_div_val - 1) begin
                beep_div_cnt <= 0;
                beep_buz <= ~beep_buz;  //��� �簢�� ����
            end else begin
                beep_div_cnt <= beep_div_cnt + 1;
            end
        end else begin
            beep_div_cnt <= 0;
            beep_buz <= 0;
        end
    end

    // --- open ���� (pulse_run) ---
    reg open_active;
    reg [2:0] open_step;
    reg [11:0] open_cnt;
    reg [11:0] open_target;
    reg open_buz;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            open_active <= 0;
            open_step <= 0;
            open_cnt <= 0;
            open_target <= 100;
        end else if (pulse_run && !open_active) begin
            open_active <= 1;
            open_step <= 0;
            open_cnt <= 0;
            open_target <= 100;
        end else if (open_active) begin
            if (tick_1ms) begin
                if (open_cnt >= open_target - 1) begin
                    open_cnt <= 0;
                    open_step <= open_step + 1;
                    if (open_step == 3)
                        open_target <= 3000;
                    else
                        open_target <= 100;

                    if (open_step == 4) begin
                        open_active <= 0;
                    end
                end else begin
                    open_cnt <= open_cnt + 1;
                end
            end
        end
    end

    wire [17:0] open_div_val = (open_step == 0) ? 18'd191213 :  // �� (�� 523Hz)
                              (open_step == 1) ? 18'd151661 :  // �� (�� 659Hz)
                              (open_step == 2) ? 18'd127551 :  // �� (�� 784Hz)
                              (open_step == 3) ? 18'd90156  :  // �� (�� 988Hz)
                                                    18'd0;

    reg [17:0] open_div_cnt;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            open_div_cnt <= 0;
            open_buz <= 0;
        end else if (open_active && open_div_val != 0) begin
            if (open_div_cnt >= open_div_val - 1) begin
                open_div_cnt <= 0;
                open_buz <= ~open_buz;
            end else begin
                open_div_cnt <= open_div_cnt + 1;
            end
        end else begin
            open_div_cnt <= 0;
            open_buz <= 0;
        end
    end

    // --- distance ���� (distance <= 5cm) ---
    reg distance_active;
    reg [1:0] distance_step;  // 0~3 : beep!beep!
    reg [11:0] distance_cnt;
    reg [11:0] distance_target;

    wire distance_trigger = (distance <= 10'd5); 

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            distance_active <= 0;
            distance_step <= 0;
            distance_cnt <= 0;
            distance_target <= 100;
        end else if (distance_trigger && !distance_active && !beep_active && !open_active) begin
            distance_active <= 1;
            distance_step <= 0;
            distance_cnt <= 0;
            distance_target <= 100;
        end else if (distance_active) begin
            if (tick_1ms) begin
                if (distance_cnt >= distance_target - 1) begin
                    distance_cnt <= 0;
                    distance_step <= distance_step + 1;
                    distance_target <= 100;

                    if (distance_step == 3) begin
                        distance_active <= 0; // ��� �ܰ� ������ ����
                    end
                end else begin
                    distance_cnt <= distance_cnt + 1;
                end
            end
        end
    end

    wire [17:0] distance_div_val = (distance_step == 0) ? 18'd39810 :   // ��
                                (distance_step == 1) ? 18'd37500 :   // ��
                                (distance_step == 2) ? 18'd39810 :   // ��
                                (distance_step == 3) ? 18'd37500 :   // ��
                                                        18'd0;

    reg [17:0] distance_div_cnt;
    reg distance_buz;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            distance_div_cnt <= 0;
            distance_buz <= 0;
        end else if (distance_active && distance_div_val != 0) begin
            if (distance_div_cnt >= distance_div_val - 1) begin
                distance_div_cnt <= 0;
                distance_buz <= ~distance_buz;
            end else begin
                distance_div_cnt <= distance_div_cnt + 1;
            end
        end else begin
            distance_div_cnt <= 0;
            distance_buz <= 0;
        end
    end
        // --- ���� ���� ��� ---
    // alarm�� �켱, ���� beep, ���� open ������ �켱���� �ο�
    assign buzzer = distance_active ? distance_buz : 
                    (beep_active ? beep_buz :
                    (open_active ? open_buz : 1'b0));

endmodule

