`timescale 1ns/1ps
import trading_pkg::*;

typedef struct packed {
    logic valid;
    side_t side;
    logic [15:0] price;
    logic [15:0] quantity;
    logic [15:0] order_id;
    logic [15:0] seq_num;
} order_t;

module order_book(
    input logic clk,
    input logic reset,

    input logic add_valid,
    input logic [15:0] add_order_id,
    input side_t add_side,
    input logic [15:0] add_price,
    input logic [15:0] add_quantity,
    input logic [15:0] cancel_order_id,
    input logic cancel_valid,

    output logic add_ready,
    output logic cancel_ready,
    output logic [15:0] best_bid_price,
    output logic [15:0] best_ask_price,
    output logic match_valid,
    output logic [15:0] match_quantity,
    output logic [15:0] match_price,
    output logic [15:0] matched_buy_id,
    output logic [15:0] matched_sell_id
);

localparam BOOK_DEPTH = 16;
localparam INDEX_WIDTH = $clog2(BOOK_DEPTH);

order_t orders [0:BOOK_DEPTH-1];

logic [INDEX_WIDTH-1:0] free_index;
logic free_found;
logic [INDEX_WIDTH-1:0] cancel_index;
logic cancel_found;
logic [15:0] next_seq_num;

always_comb begin : free_slot_search
    free_index = '0;
    free_found = 1'b0;
    
    for (int i = 0; i < BOOK_DEPTH; i++) begin
        if (!orders[i].valid && !free_found) begin
            free_index = INDEX_WIDTH'(i);
            free_found = 1'b1;
        end
    end
end

always_comb begin: cancel_slot_search
    cancel_found = 1'b0;
    cancel_index= '0;
    
    for (int i = 0; i < BOOK_DEPTH; i++) begin
        if (orders[i].valid && (orders[i].order_id == cancel_order_id)
        && !cancel_found) begin
            cancel_found = 1'b1;
            cancel_index = INDEX_WIDTH'(i);
        end
    end
end

function automatic logic [INDEX_WIDTH-1:0] better_bid(
    input logic [INDEX_WIDTH-1:0] a,
    input logic [INDEX_WIDTH-1:0] b
);

    logic a_is_buy;
    logic b_is_buy;

    begin
        a_is_buy = orders[a].valid && (orders[a].side == BUY);
        b_is_buy = orders[b].valid && (orders[b].side == BUY);

        if (a_is_buy && !b_is_buy) begin
            better_bid = a;
        end
        else if (!a_is_buy && b_is_buy) begin
            better_bid = b;
        end
        else if (a_is_buy && b_is_buy) begin
            if (orders[a].price > orders[b].price) begin
                better_bid = a;
            end
            else if (orders[a].price < orders[b].price) begin
                better_bid = b;
            end
            else if (orders[a].seq_num < orders[b].seq_num) begin
                better_bid = a;
            end
            else begin
                better_bid = b;
            end
        end
        else begin
            better_bid = a;
        end
    end

endfunction

function automatic logic [INDEX_WIDTH-1:0] better_ask(
    input logic [INDEX_WIDTH-1:0] a,
    input logic [INDEX_WIDTH-1:0] b
);

    logic a_is_ask;
    logic b_is_ask;

    begin
        a_is_ask = orders[a].valid && (orders[a].side == SELL);
        b_is_ask = orders[b].valid && (orders[b].side == SELL);

        if (a_is_ask && !b_is_ask) begin
            better_ask = a;
        end
        else if (!a_is_ask && b_is_ask) begin
            better_ask = b;
        end
        else if (a_is_ask && b_is_ask) begin
            if (orders[a].price > orders[b].price) begin
                better_ask = b;
            end
            else if (orders[a].price < orders[b].price) begin
                better_ask = a;
            end
            else if (orders[a].seq_num < orders[b].seq_num) begin
                better_ask = a;
            end
            else begin
                better_ask = b;
            end
        end
        else begin
            better_ask = a;
        end
    end

endfunction

function automatic logic better_bid_order(
    input order_t a,
    input order_t b
);

    logic a_is_buy;
    logic b_is_buy;

    begin
        a_is_buy = a.valid && (a.side == BUY);
        b_is_buy = b.valid && (b.side == BUY);

        if (a_is_buy && !b_is_buy) begin
            better_bid_order = 1'b0;
        end
        else if (!a_is_buy && b_is_buy) begin
            better_bid_order = 1'b1;
        end
        else if (a_is_buy && b_is_buy) begin
            if (a.price > b.price) begin
                better_bid_order = 1'b0;
            end
            else if (a.price < b.price) begin
                better_bid_order = 1'b1;
            end
            else if (a.seq_num < b.seq_num) begin
                better_bid_order = 1'b0;
            end
            else begin
                better_bid_order = 1'b1;
            end
        end
        else begin
            better_bid_order = 1'b0;
        end
    end

endfunction

function automatic logic better_ask_order(
    input order_t a,
    input order_t b
);

    logic a_is_ask;
    logic b_is_ask;

    begin
        a_is_ask = a.valid && (a.side == SELL);
        b_is_ask = b.valid && (b.side == SELL);

        if (a_is_ask && !b_is_ask) begin
            better_ask_order = 1'b0;
        end
        else if (!a_is_ask && b_is_ask) begin
            better_ask_order = 1'b1;
        end
        else if (a_is_ask && b_is_ask) begin

            if (a.price < b.price) begin
                better_ask_order = 1'b0;
            end
            else if (a.price > b.price) begin
                better_ask_order = 1'b1;
            end

            else if (a.seq_num < b.seq_num) begin
                better_ask_order = 1'b0;
            end
            else begin
                better_ask_order = 1'b1;
            end
        end
        else begin
            better_ask_order = 1'b0;
        end
    end

endfunction

// ============================================================
// Comparator tree signals
// ============================================================

logic [INDEX_WIDTH-1:0] bid_level1 [0:7];
logic [INDEX_WIDTH-1:0] bid_level2 [0:3];

logic [INDEX_WIDTH-1:0] ask_level1 [0:7];
logic [INDEX_WIDTH-1:0] ask_level2 [0:3];


// ============================================================
// Levels 1-2: operate directly on live order book
// ============================================================

always_comb begin : find_bid_level1_level2

    // Level 1: 16 -> 8
    for (int i = 0; i < 8; i++) begin
        bid_level1[i] = better_bid(
            INDEX_WIDTH'(2*i),
            INDEX_WIDTH'(2*i + 1)
        );
    end

    // Level 2: 8 -> 4
    for (int i = 0; i < 4; i++) begin
        bid_level2[i] = better_bid(
            bid_level1[2*i],
            bid_level1[2*i + 1]
        );
    end

end


always_comb begin : find_ask_level1_level2

    // Level 1: 16 -> 8
    for (int i = 0; i < 8; i++) begin
        ask_level1[i] = better_ask(
            INDEX_WIDTH'(2*i),
            INDEX_WIDTH'(2*i + 1)
        );
    end

    // Level 2: 8 -> 4
    for (int i = 0; i < 4; i++) begin
        ask_level2[i] = better_ask(
            ask_level1[2*i],
            ask_level1[2*i + 1]
        );
    end

end


// ============================================================
// PIPELINE STAGE 1
// Register the four Level-2 candidates.
// IMPORTANT: store BOTH index and order snapshot.
// ============================================================

logic [INDEX_WIDTH-1:0] bid_level2_reg [0:3];
logic [INDEX_WIDTH-1:0] ask_level2_reg [0:3];

order_t bid_order_level2_reg [0:3];
order_t ask_order_level2_reg [0:3];


always_ff @(posedge clk) begin
    if (reset) begin

        bid_level2_reg[0] <= '0;
        bid_level2_reg[1] <= '0;
        bid_level2_reg[2] <= '0;
        bid_level2_reg[3] <= '0;

        ask_level2_reg[0] <= '0;
        ask_level2_reg[1] <= '0;
        ask_level2_reg[2] <= '0;
        ask_level2_reg[3] <= '0;

        bid_order_level2_reg[0] <= '0;
        bid_order_level2_reg[1] <= '0;
        bid_order_level2_reg[2] <= '0;
        bid_order_level2_reg[3] <= '0;

        ask_order_level2_reg[0] <= '0;
        ask_order_level2_reg[1] <= '0;
        ask_order_level2_reg[2] <= '0;
        ask_order_level2_reg[3] <= '0;

    end
    else begin

        // BID candidates
        bid_level2_reg[0] <= bid_level2[0];
        bid_level2_reg[1] <= bid_level2[1];
        bid_level2_reg[2] <= bid_level2[2];
        bid_level2_reg[3] <= bid_level2[3];

        bid_order_level2_reg[0] <= orders[bid_level2[0]];
        bid_order_level2_reg[1] <= orders[bid_level2[1]];
        bid_order_level2_reg[2] <= orders[bid_level2[2]];
        bid_order_level2_reg[3] <= orders[bid_level2[3]];

        // ASK candidates
        ask_level2_reg[0] <= ask_level2[0];
        ask_level2_reg[1] <= ask_level2[1];
        ask_level2_reg[2] <= ask_level2[2];
        ask_level2_reg[3] <= ask_level2[3];

        ask_order_level2_reg[0] <= orders[ask_level2[0]];
        ask_order_level2_reg[1] <= orders[ask_level2[1]];
        ask_order_level2_reg[2] <= orders[ask_level2[2]];
        ask_order_level2_reg[3] <= orders[ask_level2[3]];

    end
end


// ============================================================
// Level 3
// Compare REGISTERED snapshots only.
// 4 candidates -> 2 candidates
// ============================================================

logic [INDEX_WIDTH-1:0] bid_level3 [0:1];
logic [INDEX_WIDTH-1:0] ask_level3 [0:1];

order_t bid_level3_order [0:1];
order_t ask_level3_order [0:1];


always_comb begin : find_bid_level3

    // Candidate 0 vs Candidate 1
    if (better_bid_order(
        bid_order_level2_reg[0],
        bid_order_level2_reg[1]
    ) == 1'b0) begin

        bid_level3[0]       = bid_level2_reg[0];
        bid_level3_order[0] = bid_order_level2_reg[0];

    end
    else begin

        bid_level3[0]       = bid_level2_reg[1];
        bid_level3_order[0] = bid_order_level2_reg[1];

    end


    // Candidate 2 vs Candidate 3
    if (better_bid_order(
        bid_order_level2_reg[2],
        bid_order_level2_reg[3]
    ) == 1'b0) begin

        bid_level3[1]       = bid_level2_reg[2];
        bid_level3_order[1] = bid_order_level2_reg[2];

    end
    else begin

        bid_level3[1]       = bid_level2_reg[3];
        bid_level3_order[1] = bid_order_level2_reg[3];

    end

end


always_comb begin : find_ask_level3

    // Candidate 0 vs Candidate 1
    if (better_ask_order(
        ask_order_level2_reg[0],
        ask_order_level2_reg[1]
    ) == 1'b0) begin

        ask_level3[0]       = ask_level2_reg[0];
        ask_level3_order[0] = ask_order_level2_reg[0];

    end
    else begin

        ask_level3[0]       = ask_level2_reg[1];
        ask_level3_order[0] = ask_order_level2_reg[1];

    end


    // Candidate 2 vs Candidate 3
    if (better_ask_order(
        ask_order_level2_reg[2],
        ask_order_level2_reg[3]
    ) == 1'b0) begin

        ask_level3[1]       = ask_level2_reg[2];
        ask_level3_order[1] = ask_order_level2_reg[2];

    end
    else begin

        ask_level3[1]       = ask_level2_reg[3];
        ask_level3_order[1] = ask_order_level2_reg[3];

    end

end


// ============================================================
// Level 4
// 2 candidates -> final winner
// Still using snapshots only.
// ============================================================

logic [INDEX_WIDTH-1:0] bid_level4;
logic [INDEX_WIDTH-1:0] ask_level4;

order_t bid_level4_order;
order_t ask_level4_order;


always_comb begin : final_bid_compare

    if (better_bid_order(
        bid_level3_order[0],
        bid_level3_order[1]
    ) == 1'b0) begin

        bid_level4       = bid_level3[0];
        bid_level4_order = bid_level3_order[0];

    end
    else begin

        bid_level4       = bid_level3[1];
        bid_level4_order = bid_level3_order[1];

    end

end


always_comb begin : final_ask_compare

    if (better_ask_order(
        ask_level3_order[0],
        ask_level3_order[1]
    ) == 1'b0) begin

        ask_level4       = ask_level3[0];
        ask_level4_order = ask_level3_order[0];

    end
    else begin

        ask_level4       = ask_level3[1];
        ask_level4_order = ask_level3_order[1];

    end

end


// ============================================================
// Final best bid / ask signals
// ============================================================

logic best_bid_found;
logic best_ask_found;

logic [INDEX_WIDTH-1:0] best_bid_index;
logic [INDEX_WIDTH-1:0] best_ask_index;

logic best_bid_found_reg;
logic best_ask_found_reg;

logic [INDEX_WIDTH-1:0] best_bid_index_reg;
logic [INDEX_WIDTH-1:0] best_ask_index_reg;

order_t best_bid_order_reg;
order_t best_ask_order_reg;


assign best_bid_found =
    bid_level4_order.valid &&
    (bid_level4_order.side == BUY);

assign best_bid_index = bid_level4;


assign best_ask_found =
    ask_level4_order.valid &&
    (ask_level4_order.side == SELL);

assign best_ask_index = ask_level4;


// ============================================================
// PIPELINE STAGE 2
// Register final winners
// ============================================================

always_ff @(posedge clk) begin
    if (reset) begin

        best_bid_found_reg <= 1'b0;
        best_ask_found_reg <= 1'b0;

        best_bid_index_reg <= '0;
        best_ask_index_reg <= '0;

        best_bid_order_reg <= '0;
        best_ask_order_reg <= '0;

    end
    else begin

        best_bid_found_reg <= best_bid_found;
        best_ask_found_reg <= best_ask_found;

        best_bid_index_reg <= best_bid_index;
        best_ask_index_reg <= best_ask_index;

        best_bid_order_reg <= bid_level4_order;
        best_ask_order_reg <= ask_level4_order;

    end
end


// ============================================================
// Public best-price outputs
// ============================================================

assign best_bid_price =
    best_bid_found_reg
        ? best_bid_order_reg.price
        : 16'd0;

assign best_ask_price =
    best_ask_found_reg
        ? best_ask_order_reg.price
        : 16'd0;

always_comb begin: find_match
    match_valid = 1'b0;
    match_quantity = '0;
    match_price = '0;
    matched_buy_id = '0;
    matched_sell_id = '0;

    if (best_bid_found_reg && best_ask_found_reg && 
    best_bid_order_reg.price >= best_ask_order_reg.price) begin
        match_valid = 1'b1;
        match_price = best_ask_order_reg.price;
        matched_buy_id = best_bid_order_reg.order_id;
        matched_sell_id = best_ask_order_reg.order_id;
        if (best_bid_order_reg.quantity >= best_ask_order_reg.quantity ) begin
            match_quantity = best_ask_order_reg.quantity;
        end
        else begin
            match_quantity = best_bid_order_reg.quantity;
        end
    end
end

always_ff @(posedge clk) begin
    if (reset) begin
        next_seq_num <= '0;
        for (int i = 0; i < BOOK_DEPTH; i++) begin
            orders[i].valid <= 1'b0;
        end
    end
    else if (match_valid) begin
        if (best_bid_order_reg.quantity >
            best_ask_order_reg.quantity) begin

            orders[best_bid_index_reg].quantity <=
                best_bid_order_reg.quantity -
                best_ask_order_reg.quantity;

            orders[best_ask_index_reg].valid <= 1'b0;
        end
        else if (best_bid_order_reg.quantity <
                 best_ask_order_reg.quantity) begin

            orders[best_ask_index_reg].quantity <=
                best_ask_order_reg.quantity -
                best_bid_order_reg.quantity;

            orders[best_bid_index_reg].valid <= 1'b0;
        end
        else begin
            orders[best_bid_index_reg].valid <= 1'b0;
            orders[best_ask_index_reg].valid <= 1'b0;
        end
    end
    else if (cancel_valid && cancel_ready) begin
        orders[cancel_index].valid <= 1'b0;
    end
    else if (add_valid && add_ready) begin
        orders[free_index].valid    <= 1'b1;
        orders[free_index].side     <= add_side;
        orders[free_index].price    <= add_price;
        orders[free_index].quantity <= add_quantity;
        orders[free_index].order_id <= add_order_id;
        orders[free_index].seq_num  <= next_seq_num;

        next_seq_num <= next_seq_num + 1'b1;
    end
end

assign add_ready = free_found && !match_valid && !(cancel_valid && cancel_ready);
assign cancel_ready = cancel_found && !match_valid;

endmodule
