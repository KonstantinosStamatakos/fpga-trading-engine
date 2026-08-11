`timescale 1ns/1ps
import trading_pkg::*;

module trading_engine (
    input logic clk,
    input logic reset,

    input logic [7:0]data_in,
    input logic data_valid,

    output logic [15:0] best_bid_price,
    output logic [15:0] best_ask_price,
    output logic match_valid,
    output logic [15:0] match_quantity,
    output logic [15:0] match_price,
    output logic [15:0] matched_buy_id,
    output logic [15:0] matched_sell_id
);

logic add_valid;
logic [15:0] add_order_id;
side_t add_side;
logic [15:0] add_price;
logic [15:0] add_quantity;
logic cancel_valid;
logic [15:0] cancel_order_id;
logic add_ready;
logic cancel_ready;

message_parser parser (
    .clk(clk),
    .reset(reset),
    .data_in(data_in),
    .data_valid(data_valid),
    .add_ready(add_ready),
    .cancel_ready(cancel_ready),
    .add_valid(add_valid),
    .add_order_id(add_order_id),
    .add_side(add_side),
    .add_price(add_price),
    .add_quantity(add_quantity),
    .cancel_valid(cancel_valid),
    .cancel_order_id(cancel_order_id)
);

order_book book(
    .clk(clk),
    .reset(reset),
    .add_valid(add_valid),
    .add_order_id(add_order_id),
    .add_side(add_side),
    .add_price(add_price),
    .add_quantity(add_quantity),
    .cancel_valid(cancel_valid),
    .cancel_order_id(cancel_order_id),
    .add_ready(add_ready),
    .cancel_ready(cancel_ready),
    .best_bid_price(best_bid_price),
    .best_ask_price(best_ask_price),
    .match_valid(match_valid),
    .match_quantity(match_quantity),
    .match_price(match_price),
    .matched_buy_id(matched_buy_id),
    .matched_sell_id(matched_sell_id)
);

endmodule
