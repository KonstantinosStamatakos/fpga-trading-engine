`timescale 1ns/1ps
import trading_pkg::*;

module message_parser (

    input logic clk,
    input logic reset,

    input logic [7:0] data_in,
    input logic data_valid,
    input logic add_ready,
    input logic cancel_ready,

    output logic add_valid,
    output logic [15:0] add_order_id,
    output side_t add_side,
    output logic [15:0] add_price,
    output logic [15:0] add_quantity,

    output logic cancel_valid,
    output logic [15:0] cancel_order_id

);

typedef enum logic [3:0] {
    WAIT_TYPE,
    ADD_ID_H,
    ADD_ID_L,
    ADD_SIDE,
    ADD_PRICE_H,
    ADD_PRICE_L,
    ADD_QTY_H,
    ADD_QTY_L,
    ADD_WAIT,
    CANCEL_ID_H,
    CANCEL_ID_L,
    CANCEL_WAIT
} state_t;

logic [7:0] add_order_id_h;
logic [7:0] add_price_h;
logic [7:0] add_quantity_h;
logic [7:0] cancel_order_id_h;
state_t state;

localparam logic [7:0] MSG_ADD    = 8'h01;
localparam logic [7:0] MSG_CANCEL = 8'h02;

always_ff @(posedge clk) begin
    if (reset) begin
        add_valid <= 1'b0;
        add_order_id <= '0;
        add_price <= '0;
        add_quantity <= '0;
        cancel_valid <= 1'b0;
        cancel_order_id <= '0;
        add_side <= BUY;
        add_order_id_h <= '0;
        add_price_h <= '0;
        add_quantity_h <= '0;
        cancel_order_id_h <= '0;
        state <= WAIT_TYPE;
    end
    else begin
        case (state)
            WAIT_TYPE: begin
                if (data_valid) begin
                    if (data_in == MSG_ADD) begin
                        state <= ADD_ID_H;
                    end
                    else if (data_in == MSG_CANCEL) begin
                        state <= CANCEL_ID_H;
                    end
                end
            end
            ADD_ID_H: begin
                if (data_valid) begin
                    add_order_id_h <= data_in;
                    state <= ADD_ID_L;
                end
            end
            ADD_ID_L: begin
                if (data_valid) begin
                    add_order_id <= {add_order_id_h,data_in};
                    state <= ADD_SIDE;
                end
            end
            ADD_SIDE: begin
                if (data_valid) begin
                    if (data_in == 8'd0) begin
                        add_side <= BUY;
                        state <= ADD_PRICE_H;
                    end
                    else if (data_in == 8'd1) begin
                        add_side <= SELL;
                        state <= ADD_PRICE_H;
                    end
                end
            end
            ADD_PRICE_H: begin 
                if (data_valid) begin
                    add_price_h <= data_in;
                    state <= ADD_PRICE_L;
                end
            end
            ADD_PRICE_L: begin
                if (data_valid) begin
                    add_price <= {add_price_h,data_in};
                    state <= ADD_QTY_H;
                end
            end
            ADD_QTY_H: begin
                if (data_valid) begin
                    add_quantity_h <= data_in;
                    state <= ADD_QTY_L;
                end
            end
            ADD_QTY_L: begin
                if (data_valid) begin
                    add_quantity <= {add_quantity_h,data_in};
                    add_valid <= 1'b1;
                    state <= ADD_WAIT;
                end
            end
            ADD_WAIT: begin
                if (add_ready) begin
                    add_valid <= 1'b0;
                    state <= WAIT_TYPE;
                end
            end
            CANCEL_ID_H: begin
                if (data_valid) begin
                    cancel_order_id_h <= data_in;
                    state <= CANCEL_ID_L;
                end
            end
            CANCEL_ID_L: begin
                if (data_valid) begin
                    cancel_order_id <= {cancel_order_id_h,data_in};
                    cancel_valid <= 1'b1;
                    state <= CANCEL_WAIT;
                end
            end
            CANCEL_WAIT: begin
                if (cancel_ready) begin
                    cancel_valid <= 1'b0;
                    state <= WAIT_TYPE;
                end
            end
            default: begin
                state <= WAIT_TYPE;
                add_valid <= 1'b0;
                cancel_valid <= 1'b0;
            end
        endcase
    end
end
        



endmodule
