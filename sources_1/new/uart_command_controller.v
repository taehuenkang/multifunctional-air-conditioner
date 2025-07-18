`timescale 1ns / 1ps

module uart_command_controller(
    input clk,
    input reset,
    input [7:0] rx_data, // 수신된 UART 데이터
    input rx_done,

    output btnU_command,    // 수동모드일 때 목표온도 전환
    output btnC_command,    // auto mode 전환
    output btnL_command,    // ultra <-> SR04
    output btnR_command,    // mode change
    output btnD_command,    // 수동모드일 때 목표온도 전환
    output door_command,    // sw[0]

    output reset_command,   // 시스템 리셋
    output mod0,            // minsec_stop mode
    output mod1,            // microwave mode
    output mod2             // air_conditioner mode
);

    reg btnU_command_reg, btnU_command_next;
    reg btnC_command_reg, btnC_command_next;
    reg btnL_command_reg, btnL_command_next;
    reg btnR_command_reg, btnR_command_next;
    reg btnD_command_reg, btnD_command_next;
    reg door_command_reg, door_command_next;
    reg reset_command_reg, reset_command_next;
    reg mod0_reg, mod0_next;
    reg mod1_reg, mod1_next;
    reg mod2_reg, mod2_next;

    assign btnU_command = btnU_command_reg;
    assign btnC_command = btnC_command_reg;
    assign btnL_command = btnL_command_reg;
    assign btnR_command = btnR_command_reg;
    assign btnD_command = btnD_command_reg;
    assign door_command = door_command_reg;
    assign reset_command = reset_command_reg;
    assign mod0 = mod0_reg;
    assign mod1 = mod1_reg;
    assign mod2 = mod2_reg;

    // 상태 업데이트
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            btnU_command_reg <= 0;
            btnC_command_reg <= 0;
            btnL_command_reg <= 0;
            btnR_command_reg <= 0;
            btnD_command_reg <= 0;
            door_command_reg <= 0;
            reset_command_reg <= 0;
            mod0_reg <= 0;
            mod1_reg <= 0;
            mod2_reg <= 0;
        end else begin
            btnU_command_reg <= btnU_command_next;
            btnC_command_reg <= btnC_command_next;
            btnL_command_reg <= btnL_command_next;
            btnR_command_reg <= btnR_command_next;
            btnD_command_reg <= btnD_command_next;
            door_command_reg <= door_command_next;
            reset_command_reg <= reset_command_next;
            mod0_reg <= mod0_next;
            mod1_reg <= mod1_next;
            mod2_reg <= mod2_next;
        end
    end

    // 조합 논리로 다음 상태 결정
    always @(*) begin
        // 기본값은 현재 상태 유지
        btnU_command_next = btnU_command_reg;
        btnC_command_next = btnC_command_reg;
        btnL_command_next = btnL_command_reg;
        btnR_command_next = btnR_command_reg;
        btnD_command_next = btnD_command_reg;
        door_command_next = door_command_reg;
        reset_command_next = reset_command_reg;
        mod0_next = mod0_reg;
        mod1_next = mod1_reg;
        mod2_next = mod2_reg;

        // rx_done이 떴을 때만 변경
        if (rx_done) begin
            // 새 신호가 들어오면 기존 상태는 리셋(0)하고 해당 신호만 1로 세팅
            btnU_command_next = 0;
            btnC_command_next = 0;
            btnL_command_next = 0;
            btnR_command_next = 0;
            btnD_command_next = 0;
            door_command_next = 0;
            reset_command_next = 0;
            mod0_next = 0;
            mod1_next = 0;
            mod2_next = 0;

            case (rx_data)
                8'h55, 8'h75: btnU_command_next = 1;   // 'U' or 'u'
                8'h44, 8'h64: btnD_command_next = 1;   // 'D' or 'd'
                8'h52, 8'h72: btnR_command_next = 1;   // 'R' or 'r'
                8'h4C, 8'h6C: btnL_command_next = 1;   // 'L' or 'l'
                8'h43, 8'h63: btnC_command_next = 1;   // 'C' or 'c'
                8'h4F: door_command_next = 1;   // 'O'
                8'h5A: reset_command_next = 1;  // 'Z'
                8'h30: mod0_next = 1;           // '0'
                8'h31: mod1_next = 1;           // '1'
                8'h32: mod2_next = 1;           // '2'
                default: begin
                    // 바뀌지 않음
                end
            endcase
        end else begin
            // rx_done 신호 없으면 모두 0으로 초기화해서 1클럭 펄스로 동작하도록 할 수도 있음
            // 필요에 따라 유지하려면 여기서도 이전 상태 유지할 수 있음
            btnU_command_next = 0;
            btnC_command_next = 0;
            btnL_command_next = 0;
            btnR_command_next = 0;
            btnD_command_next = 0;
            door_command_next = 0;
            reset_command_next = 0;
            mod0_next = 0;
            mod1_next = 0;
            mod2_next = 0;
        end
    end

endmodule
