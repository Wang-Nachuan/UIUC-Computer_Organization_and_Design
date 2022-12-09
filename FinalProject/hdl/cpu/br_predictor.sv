module br_predictor 
import rv32i_types::*;
#(
    // parameter tag_width = 30, // 32-2 = 30
    parameter depth_bht = DEPTH_BH_TABLE, // 32 entries br table 
    parameter depth_pht = DEPTH_PH_TABLE,
    parameter size_bh_his = SIZE_BH_TABLE,
    parameter size_global_his = SIZE_GLOBAL_HIS,
    parameter size_global = SIZE_GLOBAL,
    parameter size_counter = 2, //size_ph_table
    parameter size_br_counter = 12,
    parameter depth_counter_table = 64,
    parameter depth_gshare_table = DEPTH_PH_TABLE_GSHARE,
    parameter size_gshare_index = SIZE_GSHARE_TABLE
)
(
    input logic clk,
    input logic rst,
    //predicting
    input logic predicting,
    input rv32i_word fetch_pc,
    output logic need_jump,

    input logic predicting_pc_next,
    input rv32i_word fetch_pc_next,
    output logic need_jump_next,

    output logic [size_global-1:0] br_history_new,
    //comparing and update
    input logic updating,
    input logic br_op,
    input rv32i_word update_pc,
    input logic br_en,
    input logic [size_global-1:0] br_history_old,
    input logic pred_correct
);
/**************2 level branch history table used ********************/
typedef enum logic[1:0] {
    ST = 2'b00,
    WT = 2'b01,
    WNT = 2'b11,
    SNT = 2'b10
} br_counter_2;
logic updated;
assign updated = updating && br_op;

logic [size_global_his-1:0] global_history;
logic [size_global_his-1:0] global_history_old;
logic [size_counter-1:0] ph_table [depth_pht-1:0];
logic [$clog2(depth_pht)-1:0] bh_table[depth_bht-1:0];
logic need_jump1;

logic pc_next_predicted;
logic [size_global_his-1:0] global_hist_buffer;
logic [1:0] method_equal_buffer;
logic [1:0] method_equal_pc_next;

logic [1:0] method_equal_new; //  which method is used, and if two methods have the same predict result
logic [1:0] method_equal_old; 

logic [$clog2(depth_bht)-1:0] fetch_pc_id_next;

logic [$clog2(depth_bht)-1:0] fetch_pc_id;
logic [$clog2(depth_bht)-1:0] update_pc_id;

logic [size_gshare_index-1:0] fetch_pc_gshare_id;
logic [size_gshare_index-1:0] update_pc_gshare_id;
logic [size_gshare_index-1:0] fetch_pc_gshare_id_next;


always_comb begin
    if(pc_next_predicted) begin
        br_history_new = {global_hist_buffer,method_equal_buffer};
    end
    else begin
        br_history_new = {global_history,method_equal_new};
    end
end
assign {global_history_old,method_equal_old} =  br_history_old;

/**********************************************/
/**************Bit combination*****************/
/*********************************************/
assign fetch_pc_id = global_history ^ fetch_pc[2+:SIZE_GLOBAL_HIS];
assign update_pc_id = global_history_old ^ update_pc[2+:SIZE_GLOBAL_HIS];
assign fetch_pc_id_next = global_history ^ fetch_pc_next[2+:SIZE_GLOBAL_HIS];

assign fetch_pc_gshare_id = global_history[0+:SIZE_GSHARE_TABLE] ^ fetch_pc[2+:SIZE_GSHARE_TABLE];
assign update_pc_gshare_id = global_history_old[0+:SIZE_GSHARE_TABLE] ^ update_pc[2+:SIZE_GSHARE_TABLE];
assign fetch_pc_gshare_id_next = global_history[0+:SIZE_GSHARE_TABLE] ^ fetch_pc_next[2+:SIZE_GSHARE_TABLE];

/********************************************/
/********************************************/

//update pht
logic [$clog2(depth_pht)-1:0] fetch_bht_id; //HIST in BHT
logic [$clog2(depth_pht)-1:0] update_bht_id; //HIST in BHT
logic [$clog2(depth_pht)-1:0] fetch_pht_id;
logic [$clog2(depth_pht)-1:0] update_pht_id;

logic [$clog2(depth_pht)-1:0] fetch_bht_id_next;
logic [$clog2(depth_pht)-1:0] fetch_pht_id_next;

assign fetch_bht_id = bh_table[fetch_pc_id];
assign update_bht_id = bh_table[update_pc_id];

/**********************************************/
/**************Bit combination*****************/
/*********************************************/
assign fetch_pht_id = fetch_bht_id ^ fetch_pc[2+:size_bh_his];
assign update_pht_id = update_bht_id ^ update_pc[2+:size_bh_his];
assign fetch_pht_id_next = fetch_bht_id_next ^ fetch_pc_next[2+:size_bh_his];
/********************************************/
/********************************************/

assign fetch_bht_id_next = bh_table[fetch_pc_id_next];

logic need_jump1_next;
logic need_jump2_next;

/**************Gshare used ********************/
logic [size_counter-1:0] gshare_table [depth_gshare_table-1:0];
logic need_jump2;

/**************Counter table for tournament br predictor********************/
logic [size_br_counter-1:0] counter_table_1 [depth_counter_table-1:0]; // 2 level global share
logic [size_br_counter-1:0] counter_table_2 [depth_counter_table-1:0]; // Gshare
logic [$clog2(depth_counter_table)-1:0] ptr; // pointer
logic [size_br_counter-1:0] pc_tag [depth_counter_table-1:0];
logic [depth_counter_table-1:0] counter_valid;
logic fetch_pc_intable;
logic update_pc_intable;
logic [$clog2(depth_counter_table)-1:0] fetch_pc_counter_id;
logic [$clog2(depth_counter_table)-1:0] update_pc_counter_id;

logic [$clog2(depth_counter_table)-1:0] fetch_pc_counter_id_next;

// check fetch_pc and update_pc in table, record the counter id
always_comb begin
    fetch_pc_intable = 1'b0;
    update_pc_intable = 1'b0;
    fetch_pc_counter_id = {$clog2(depth_counter_table){1'b0}};
    update_pc_counter_id = {$clog2(depth_counter_table){1'b0}};
    fetch_pc_counter_id_next = {$clog2(depth_counter_table){1'b0}};
    for (int i = 0; i<depth_counter_table; i++) begin
        if(counter_valid[i] & (pc_tag[i] == fetch_pc[2+:size_br_counter])) begin
            fetch_pc_intable = 1'b1;
            fetch_pc_counter_id = i[$clog2(depth_counter_table)-1:0];
        end
        if(counter_valid[i] & (pc_tag[i] == update_pc[2+:size_br_counter])) begin
            update_pc_intable = 1'b1;
            update_pc_counter_id = i[$clog2(depth_counter_table)-1:0];
        end
    end
    for (int i = 0; i<depth_counter_table; i++) begin
        if(counter_valid[i] & (pc_tag[i] == fetch_pc_next[2+:size_br_counter])) begin
            fetch_pc_counter_id_next = i[$clog2(depth_counter_table)-1:0];
        end
    end
end
// update tag, valid, counter
always_ff @(posedge clk) begin
    if (rst) begin
        ptr <= {$clog2(depth_counter_table){1'b0}};
        counter_valid <= {depth_counter_table{1'b0}};
        for(int i = 0; i < depth_counter_table; i++) begin
            pc_tag[i] <= {size_br_counter{1'b0}};
            counter_table_1[i] <= {size_br_counter{1'b0}};
            counter_table_2[i] <= {size_br_counter{1'b0}};
        end
    end
    else if (predicting & (~fetch_pc_intable)) begin
        pc_tag[ptr] <= fetch_pc[2+:size_br_counter];
        counter_valid[ptr] <= 1'b1;
        ptr <= ptr + {{($clog2(depth_counter_table)-1){1'b0}}, 1'b1};
        counter_table_1[ptr] <= {size_br_counter{1'b0}};
        counter_table_2[ptr] <= {size_br_counter{1'b0}};
    end
    else if (updated & update_pc_intable) begin
        if(pred_correct) begin
            unique case (method_equal_old) 
                // 2 level used and not equal, update counter_table_2
                2'b00: counter_table_2[update_pc_counter_id] <= counter_table_2[update_pc_counter_id] + {{(size_br_counter-1){1'b0}}, 1'b1};
                2'b01: ;
                // Gshare used and not equal, update counter_table_2
                2'b10: counter_table_1[update_pc_counter_id] <= counter_table_1[update_pc_counter_id] + {{(size_br_counter-1){1'b0}}, 1'b1};
                2'b11: ;
                default: ;
            endcase
        end
        else begin
            unique case (method_equal_old) 
                // 2 level used and not equal, update counter_table_1
                2'b00: counter_table_1[update_pc_counter_id] <= counter_table_1[update_pc_counter_id] + {{(size_br_counter-1){1'b0}}, 1'b1};
                2'b01: ;
                2'b10: counter_table_2[update_pc_counter_id] <= counter_table_2[update_pc_counter_id] + {{(size_br_counter-1){1'b0}}, 1'b1};
                2'b11: ;
                default: ;   
            endcase         
        end
    end
end

always_ff @(posedge clk) begin
    if(rst) begin
        pc_next_predicted <= 1'b0;
        global_hist_buffer <= {{size_global_his}{1'b0}};
        method_equal_buffer <= 2'b0;
    end
    if(predicting_pc_next) begin
        pc_next_predicted <= 1'b1;
        global_hist_buffer <= global_history;
        method_equal_buffer <= method_equal_pc_next;
    end
    else if(predicting) begin
        pc_next_predicted <= 1'b0;
    end
end

always_comb begin
    need_jump = 1'b0;
    need_jump1 = 1'b0;
    need_jump2 = 1'b0;
    need_jump_next = 1'b0;
    need_jump1_next = 1'b0;
    need_jump2_next = 1'b0;

    if(predicting) begin
        unique case (ph_table[fetch_pht_id])
            ST: need_jump1 = 1'b1;
            WT: need_jump1 = 1'b1;
            WNT: need_jump1 = 1'b0;
            SNT: need_jump1 = 1'b0;
            default:;
        endcase
        unique case (gshare_table[fetch_pc_gshare_id])
            ST: need_jump2 = 1'b1;
            WT: need_jump2 = 1'b1;
            WNT: need_jump2 = 1'b0;
            SNT: need_jump2 = 1'b0;   
            default:;
        endcase   
        if(counter_table_2[fetch_pc_counter_id] > counter_table_1[fetch_pc_counter_id])  begin
            need_jump = need_jump1;
            if (need_jump1 == need_jump2) begin
                method_equal_new = 2'b01;
            end
            else begin
                method_equal_new = 2'b00;
            end
        end
        else begin
            need_jump = need_jump2;
            if (need_jump1 == need_jump2) begin
                method_equal_new = 2'b11;
            end
            else begin
                method_equal_new = 2'b10;
            end
        end
    end
    else begin
        need_jump = 1'b0;
    end
    if(predicting_pc_next) begin
        unique case (ph_table[fetch_pht_id_next])
            ST: need_jump1_next = 1'b1;
            WT: need_jump1_next = 1'b1;
            WNT: need_jump1_next = 1'b0;
            SNT: need_jump1_next = 1'b0;
            default:;
        endcase
        unique case (gshare_table[fetch_pc_gshare_id_next])
            ST: need_jump2_next = 1'b1;
            WT: need_jump2_next = 1'b1;
            WNT: need_jump2_next = 1'b0;
            SNT: need_jump2_next = 1'b0;   
            default:;
        endcase   
        if(counter_table_2[fetch_pc_counter_id_next] > counter_table_1[fetch_pc_counter_id_next])  begin
            need_jump_next = need_jump1_next;
            if (need_jump1_next == need_jump2_next) begin
                method_equal_pc_next = 2'b01;
            end
            else begin
                method_equal_pc_next = 2'b00;
            end
        end
        else begin
            need_jump_next = need_jump2_next;
            if (need_jump1_next == need_jump2_next) begin
                method_equal_pc_next = 2'b11;
            end
            else begin
                method_equal_pc_next = 2'b10;
            end
        end
    end
    else begin
        need_jump_next = 1'b0;
    end
end
always_ff @(posedge clk) begin
    if (rst) begin
        global_history <= {{size_global_his}{1'b0}};
        for (int i = 0; i < depth_pht ; i++) begin
            ph_table[i] <= WT;
        end
        for (int i = 0; i < depth_gshare_table ; i++) begin
            gshare_table[i] <= WT;
        end
    end
    else if (updated) begin
        global_history <= {global_history[size_global_his-2:0],br_en};
        if (br_en) begin
            unique case(ph_table[update_pht_id])
                ST:ph_table[update_pht_id]<= ST;
                WT:ph_table[update_pht_id]<= ST;
                WNT:ph_table[update_pht_id]<= WT;
                SNT:ph_table[update_pht_id]<= WNT;
                default:;
            endcase
            unique case(gshare_table[update_pc_gshare_id])
                ST:gshare_table[update_pc_gshare_id]<= ST;
                WT:gshare_table[update_pc_gshare_id]<= ST;
                WNT:gshare_table[update_pc_gshare_id]<= WT;
                SNT:gshare_table[update_pc_gshare_id]<= WNT;
                default:;
            endcase
        end
        else begin
            unique case(ph_table[update_pht_id])
                ST:ph_table[update_pht_id]<= WT;
                WT:ph_table[update_pht_id]<= WNT;
                WNT:ph_table[update_pht_id]<= SNT;
                SNT:ph_table[update_pht_id]<= SNT;
                default:;
            endcase
            unique case(gshare_table[update_pc_gshare_id])
                ST:gshare_table[update_pc_gshare_id]<= WT;
                WT:gshare_table[update_pc_gshare_id]<= WNT;
                WNT:gshare_table[update_pc_gshare_id]<= SNT;
                SNT:gshare_table[update_pc_gshare_id]<= SNT;
                default:;
            endcase
        end
    end
end
// update BHT
always_ff @(posedge clk) begin
    if (rst) begin
        for (int i = 0; i < depth_bht ; i++) begin
            bh_table[i] <= {{size_bh_his}{1'b0}};
        end
    end
    else if (updated) begin
        bh_table[update_bht_id] <= {bh_table[update_bht_id][size_bh_his-2:0],br_en};
    end
end

endmodule
