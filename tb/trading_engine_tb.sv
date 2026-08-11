`timescale 1ns/1ps

import trading_pkg::*;

module trading_engine_tb;

localparam CLK_PERIOD = 10;

logic clk;
logic reset;

logic [7:0] data_in;
logic       data_valid;

logic [15:0] best_bid_price;
logic [15:0] best_ask_price;

logic        match_valid;
logic [15:0] match_quantity;
logic [15:0] match_price;
logic [15:0] matched_buy_id;
logic [15:0] matched_sell_id;

logic        match_seen;
logic [15:0] captured_buy_id;
logic [15:0] captured_sell_id;
logic [15:0] captured_quantity;
logic [15:0] captured_price;

int latency_cycles;
logic measuring_latency;

trading_engine uut (
    .clk(clk),
    .reset(reset),
    .data_in(data_in),
    .data_valid(data_valid),
    .best_bid_price(best_bid_price),
    .best_ask_price(best_ask_price),
    .match_valid(match_valid),
    .match_quantity(match_quantity),
    .match_price(match_price),
    .matched_buy_id(matched_buy_id),
    .matched_sell_id(matched_sell_id)
);

always #(CLK_PERIOD / 2) clk = ~clk;

always @(posedge clk) begin
    if (reset) begin
        match_seen        <= 1'b0;
        captured_buy_id   <= '0;
        captured_sell_id  <= '0;
        captured_quantity <= '0;
        captured_price    <= '0;
    end
    else if (match_valid) begin
        match_seen        <= 1'b1;
        captured_buy_id   <= matched_buy_id;
        captured_sell_id  <= matched_sell_id;
        captured_quantity <= match_quantity;
        captured_price    <= match_price;
    end
end

always @(posedge clk) begin
    if (reset) begin
        latency_cycles    <= 0;
        measuring_latency <= 1'b0;
    end
    else begin
        if (measuring_latency)
            latency_cycles <= latency_cycles + 1;

        if (match_valid)
            measuring_latency <= 1'b0;
    end
end

task automatic send_byte(
    input logic [7:0] byte_data
);

begin
    @(negedge clk);
    data_in    = byte_data;
    data_valid = 1'b1;

    @(negedge clk);
    data_valid = 1'b0;
end

endtask

task automatic send_add(
    input logic [15:0] order_id,
    input side_t       side,
    input logic [15:0] price,
    input logic [15:0] quantity
);

begin
    send_byte(8'h01);
    send_byte(order_id[15:8]);
    send_byte(order_id[7:0]);
    send_byte({7'd0, side});
    send_byte(price[15:8]);
    send_byte(price[7:0]);
    send_byte(quantity[15:8]);
    send_byte(quantity[7:0]);
end

endtask

task automatic send_cancel(
    input logic [15:0] order_id
);

begin
    send_byte(8'h02);
    send_byte(order_id[15:8]);
    send_byte(order_id[7:0]);
end

endtask

task automatic do_reset;

begin
    @(negedge clk);
    reset = 1'b1;

    repeat (2)
        @(posedge clk);

    @(negedge clk);
    reset = 1'b0;

    match_seen = 1'b0;
end

endtask

task automatic clear_match_capture;

begin
    @(negedge clk);
    match_seen        = 1'b0;
    captured_buy_id   = '0;
    captured_sell_id  = '0;
    captured_quantity = '0;
    captured_price    = '0;
end

endtask

initial begin

    $dumpfile("sim/trading_engine.vcd");
    $dumpvars(0, trading_engine_tb);

    clk = 1'b0;
    reset = 1'b1;
    data_in = '0;
    data_valid = 1'b0;

    match_seen = 1'b0;
    captured_buy_id = '0;
    captured_sell_id = '0;
    captured_quantity = '0;
    captured_price = '0;

    latency_cycles = 0;
    measuring_latency = 1'b0;

    repeat (2)
        @(posedge clk);

    @(negedge clk);
    reset = 1'b0;

    $display("");
    $display("TEST 1: ADD BUY");

    send_add(
        16'd10,
        BUY,
        16'd10000,
        16'd50
    );

    repeat (6)
        @(posedge clk);

    if (best_bid_price !== 16'd10000) begin
        $display("FAIL TEST 1: best_bid_price=%0d expected 10000",
                 best_bid_price);
        $finish;
    end

    if (best_ask_price !== 16'd0) begin
        $display("FAIL TEST 1: best_ask_price=%0d expected 0",
                 best_ask_price);
        $finish;
    end

    if (match_seen !== 1'b0) begin
        $display("FAIL TEST 1: unexpected match");
        $finish;
    end

    $display("PASS TEST 1");

    $display("");
    $display("TEST 2: ADD SELL without match");

    send_add(
        16'd20,
        SELL,
        16'd10010,
        16'd30
    );

    repeat (4)
        @(posedge clk);

    @(negedge clk);

    if (best_bid_price !== 16'd10000) begin
        $display("FAIL TEST 2: best_bid_price=%0d expected 10000",
                 best_bid_price);
        $finish;
    end

    if (best_ask_price !== 16'd10010) begin
        $display("FAIL TEST 2: best_ask_price=%0d expected 10010",
                 best_ask_price);
        $finish;
    end

    if (match_seen !== 1'b0) begin
        $display("FAIL TEST 2: unexpected match");
        $finish;
    end

    $display("PASS TEST 2");

    clear_match_capture();

    $display("");
    $display("TEST 3: Crossing BUY");

    send_add(
        16'd30,
        BUY,
        16'd10020,
        16'd20
    );

    repeat (8)
        @(posedge clk);

    if (match_seen !== 1'b1) begin
        $display("FAIL TEST 3: match not captured");
        $finish;
    end

    if (captured_buy_id !== 16'd30) begin
        $display("FAIL TEST 3: buy_id=%0d expected 30",
                 captured_buy_id);
        $finish;
    end

    if (captured_sell_id !== 16'd20) begin
        $display("FAIL TEST 3: sell_id=%0d expected 20",
                 captured_sell_id);
        $finish;
    end

    if (captured_quantity !== 16'd20) begin
        $display("FAIL TEST 3: quantity=%0d expected 20",
                 captured_quantity);
        $finish;
    end

    if (captured_price !== 16'd10010) begin
        $display("FAIL TEST 3: price=%0d expected 10010",
                 captured_price);
        $finish;
    end

    @(posedge clk);
    @(negedge clk);

    if (best_bid_price !== 16'd10000) begin
        $display("FAIL TEST 3: best_bid_price=%0d expected 10000",
                 best_bid_price);
        $finish;
    end

    if (best_ask_price !== 16'd10010) begin
        $display("FAIL TEST 3: best_ask_price=%0d expected 10010",
                 best_ask_price);
        $finish;
    end

    $display("PASS TEST 3");

    $display("");
    $display("TEST 4: CANCEL");

    send_cancel(16'd10);

    repeat (6)
        @(posedge clk);

    if (best_bid_price !== 16'd0) begin
        $display("FAIL TEST 4: best_bid_price=%0d expected 0",
                 best_bid_price);
        $finish;
    end

    if (best_ask_price !== 16'd10010) begin
        $display("FAIL TEST 4: best_ask_price=%0d expected 10010",
                 best_ask_price);
        $finish;
    end

    $display("PASS TEST 4");

    do_reset();

    $display("");
    $display("TEST 5: Price-time priority");

    send_add(
        16'd100,
        BUY,
        16'd10030,
        16'd10
    );

    repeat (8)
        @(posedge clk);

    send_add(
        16'd110,
        BUY,
        16'd10030,
        16'd10
    );

    repeat (8)
        @(posedge clk);

    clear_match_capture();

    send_add(
        16'd120,
        SELL,
        16'd10025,
        16'd10
    );

    repeat (8)
        @(posedge clk);

    if (match_seen !== 1'b1) begin
        $display("FAIL TEST 5: match not captured");
        $finish;
    end

    if (captured_buy_id !== 16'd100) begin
        $display("FAIL TEST 5: buy_id=%0d expected 100",
                 captured_buy_id);
        $finish;
    end

    if (captured_sell_id !== 16'd120) begin
        $display("FAIL TEST 5: sell_id=%0d expected 120",
                 captured_sell_id);
        $finish;
    end

    if (captured_quantity !== 16'd10) begin
        $display("FAIL TEST 5: quantity=%0d expected 10",
                 captured_quantity);
        $finish;
    end

    if (captured_price !== 16'd10025) begin
        $display("FAIL TEST 5: price=%0d expected 10025",
                 captured_price);
        $finish;
    end

    if (best_bid_price !== 16'd10030) begin
        $display("FAIL TEST 5: remaining best bid=%0d expected 10030",
                 best_bid_price);
        $finish;
    end

    $display("PASS TEST 5");

    do_reset();

    $display("");
    $display("TEST 6: Partial fill");

    send_add(
        16'd200,
        BUY,
        16'd10030,
        16'd50
    );

    repeat (8)
        @(posedge clk);

    clear_match_capture();

    send_add(
        16'd210,
        SELL,
        16'd10025,
        16'd20
    );

    repeat (8)
        @(posedge clk);

    if (match_seen !== 1'b1) begin
        $display("FAIL TEST 6: match not captured");
        $finish;
    end

    if (captured_buy_id !== 16'd200) begin
        $display("FAIL TEST 6: buy_id=%0d expected 200",
                 captured_buy_id);
        $finish;
    end

    if (captured_sell_id !== 16'd210) begin
        $display("FAIL TEST 6: sell_id=%0d expected 210",
                 captured_sell_id);
        $finish;
    end

    if (captured_quantity !== 16'd20) begin
        $display("FAIL TEST 6: quantity=%0d expected 20",
                 captured_quantity);
        $finish;
    end

    if (captured_price !== 16'd10025) begin
        $display("FAIL TEST 6: price=%0d expected 10025",
                 captured_price);
        $finish;
    end

    if (best_bid_price !== 16'd10030) begin
        $display("FAIL TEST 6: best_bid_price=%0d expected 10030",
                 best_bid_price);
        $finish;
    end

    if (best_ask_price !== 16'd0) begin
        $display("FAIL TEST 6: best_ask_price=%0d expected 0",
                 best_ask_price);
        $finish;
    end

    $display("PASS TEST 6");

    do_reset();

    $display("");
    $display("TEST 7: End-to-end latency");

    send_add(
        16'd310,
        SELL,
        16'd10010,
        16'd10
    );

    repeat (8)
        @(posedge clk);

    clear_match_capture();

    latency_cycles = 0;
    measuring_latency = 1'b1;

    send_add(
        16'd300,
        BUY,
        16'd10020,
        16'd10
    );

    wait (match_seen == 1'b1);

    @(posedge clk);

    if (captured_buy_id !== 16'd300) begin
        $display("FAIL TEST 7: wrong BUY ID");
        $finish;
    end

    if (captured_sell_id !== 16'd310) begin
        $display("FAIL TEST 7: wrong SELL ID");
        $finish;
    end

    $display(
        "PASS TEST 7: End-to-end latency = %0d cycles",
        latency_cycles
    );

    $display("");
    $display("======================================");
    $display("ALL TRADING ENGINE TESTS PASSED");
    $display("======================================");
    $display("");

    repeat (5)
        @(posedge clk);

    $finish;

end

endmodule
