module dht11_controller(
    input clk,
    input reset,
    output reg [7:0] humidity,
    output reg [7:0] current_temperature,
    inout dht11_data
);
    localparam  IDLE = 0,
                START = 1,
                WAIT = 2,
                SYNCL = 3,
                SYNCH = 4,
                DATA_SYNC = 5,
                DATA_DETECT = 6,
                STOP = 7;

    wire w_tick, w_tick_1us;
    reg [2:0] c_state, n_state;
    reg [$clog2(1900) -1:0] t_cnt_reg, t_cnt_next;
    reg [$clog2(1900) -1:0] t_cnt_reg_1us, t_cnt_next_1us;
    reg [$clog2(1900) -1:0] check_cnt_reg, check_cnt_next;
    reg dht11_reg, dht11_next;
    reg io_en_reg, io_en_next;
    reg [39:0] data_reg, data_next;
    reg valid_reg, valid_next;
    reg dht11_done_reg, dht11_done_next;

    assign dht11_data = (io_en_reg) ? dht11_reg : 1'bz;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= 0;
            t_cnt_reg <= 0;
            t_cnt_reg_1us <= 0;
            dht11_reg <= 1;
            io_en_reg <= 1;
            data_reg <= 0;
            valid_reg <= 0;
            dht11_done_reg <= 0;
            check_cnt_reg <= 0;
            humidity <= 0;
            current_temperature <= 0;
        end else begin
            c_state <= n_state;
            t_cnt_reg <= t_cnt_next;
            dht11_reg <= dht11_next;
            io_en_reg <= io_en_next;
            data_reg <= data_next;
            valid_reg <= valid_next;
            dht11_done_reg <= dht11_done_next;
            t_cnt_reg_1us <= t_cnt_next_1us;
            check_cnt_reg <= check_cnt_next;

            // 데이터 유효 시 업데이트
            if (dht11_done_next && valid_next) begin
                humidity <= data_next[39:32];
                current_temperature <= data_next[23:16];
            end
        end
    end

    always @(*) begin
        n_state = c_state;
        t_cnt_next = t_cnt_reg;
        t_cnt_next_1us = t_cnt_reg_1us;
        dht11_next = dht11_reg;
        io_en_next = io_en_reg;
        data_next = data_reg;
        valid_next = valid_reg;
        dht11_done_next = dht11_done_reg;
        check_cnt_next = check_cnt_reg;

        case (c_state)
            IDLE: begin
                dht11_done_next = 0;
                dht11_next = 1;
                io_en_next = 1;
                n_state = START;
            end
            START: begin
                if (w_tick) begin
                    dht11_next = 0;
                    if (t_cnt_reg == 1900) begin
                        n_state = WAIT;
                        t_cnt_next = 0;
                    end else begin
                        t_cnt_next = t_cnt_reg + 1;
                    end
                end
            end
            WAIT: begin
                dht11_next = 1;
                if (w_tick) begin
                    if (t_cnt_reg == 2) begin
                        n_state = SYNCL;
                        t_cnt_next = 0;
                        io_en_next = 0;
                    end else begin
                        t_cnt_next = t_cnt_reg + 1;
                    end
                end
            end
            SYNCL: begin
                if (w_tick && dht11_data) begin
                    n_state = SYNCH;
                end
            end
            SYNCH: begin
                if (w_tick && !dht11_data) begin
                    n_state = DATA_SYNC;
                end
            end
            DATA_SYNC: begin
                if (t_cnt_reg == 40) begin
                    n_state = STOP;
                    t_cnt_next = 0;
                end else if (w_tick && dht11_data) begin
                    n_state = DATA_DETECT;
                end
            end
            DATA_DETECT: begin
                if (w_tick_1us) begin
                    if (dht11_data) begin
                        t_cnt_next_1us = t_cnt_reg_1us + 1;
                    end else begin
                        if (t_cnt_reg_1us >= 40) begin
                            data_next = {data_reg[38:0], 1'b1};
                        end else begin
                            data_next = {data_reg[38:0], 1'b0};
                        end
                        t_cnt_next_1us = 0;
                        t_cnt_next = t_cnt_reg + 1;
                        if (t_cnt_reg == 39) n_state = STOP;
                        else n_state = DATA_SYNC;
                    end
                end
            end
            STOP: begin
                if (w_tick_1us) begin
                    if (t_cnt_reg_1us == 49) begin
                        n_state = IDLE;
                        dht11_done_next = 1;
                        t_cnt_next = 0;
                        t_cnt_next_1us = 0;

                        if (data_reg[7:0] == (data_reg[15:8] + data_reg[23:16] +
                                              data_reg[31:24] + data_reg[39:32])) begin
                            valid_next = 1;
                        end else valid_next = 0;
                    end else begin
                        t_cnt_next_1us = t_cnt_reg_1us + 1;
                    end
                end
            end
        endcase
    end

    tick_gen_10us U_TICK (
        .clk(clk),
        .rst(reset),
        .o_tick(w_tick)
    );

    tick_gen_1us U_TICK_1US (
        .clk(clk),
        .rst(reset),
        .o_tick(w_tick_1us)
    );
endmodule


module tick_gen_10us (
    input clk,
    input rst,
    output reg o_tick
);
    localparam F_CNT = 1000;
    reg [$clog2(F_CNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
        end else begin
            if (counter_reg >= F_CNT - 1) begin
                counter_reg <= 0;
                o_tick <= 1;
            end else begin
                counter_reg <= counter_reg + 1;
                o_tick <= 0;
            end
        end
    end

endmodule


module tick_gen_1us (
    input clk,
    input rst,
    output reg o_tick
);
    localparam F_CNT = 100;
    reg [$clog2(F_CNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
        end else begin
            if (counter_reg >= F_CNT - 1) begin
                counter_reg <= 0;
                o_tick <= 1;
            end else begin
                counter_reg <= counter_reg + 1;
                o_tick <= 0;
            end
        end
    end

endmodule