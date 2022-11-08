module regfile
import rv32i_types::*;
#(
    parameter len_id = LEN_ID
)
(
    input logic clk,
    input logic rst,

    // Issue
    input logic issue_req,
    input logic issue_isrd,
    input logic [4:0] issue_rd,
    input logic [len_id-1:0] rob_id,

    // Commit
    input logic commit_rf_en,
    input logic [4:0] commit_rd,
    input logic [31:0] commit_data,
    input logic [LEN_ID-1:0] commit_id,

    // Flush
    input logic flush_rf_en,
    input logic [31:0] flush_dep_rf_en,
    input logic [31:0][len_id-1:0] flush_dep_rf,

    // Read
    // sr1
    input logic [4:0] issue_sr1,
    output logic rf_sr1_rdy,
    output logic [len_id-1:0] rf_sr1_id,
    output logic [31:0] rf_sr1_val,
    // sr2
    input logic [4:0] issue_sr2,
    output logic rf_sr2_rdy,
    output logic [len_id-1:0] rf_sr2_id,
    output logic [31:0] rf_sr2_val
);

logic [31:0] isdep, isdep_n;
logic [31:0][len_id-1:0] id, id_n;
logic [31:0][31:0] data, data_n;

// Update internal state (ff)
always_ff @(posedge clk) begin
    isdep[0] <= 1'b0;
    id[0] <= {len_id{1'b0}};
    data[0] <= 32'b0;

    for (int i=1; i<32; i++) begin
        if (rst) begin
            isdep[i] <= 1'b0;
            id[i] <= {len_id{1'b0}};
            data[i] <= 32'b0;
        end
        else begin
            isdep[i] <= isdep_n[i];
            id[i] <= id_n[i];
            data[i] <= data_n[i];
        end
    end
end

// Update internal state (comb)
always_comb begin
    /* Order of if-statements is important */
    // Default
    isdep_n[31:1] = isdep[31:1];
    id_n[31:1] = id[31:1];
    data_n[31:1] = data[31:1];

    // Commit
    if (commit_rf_en && commit_rd) begin
        if (isdep[commit_rd] && commit_id == id[commit_rd])
            isdep_n[commit_rd] = 1'b0;
        data_n[commit_rd] = commit_data;
    end

    // Issue 
    if (issue_req && issue_isrd && issue_rd) begin
        isdep_n[issue_rd] = 1'b1;
        id_n[issue_rd] = rob_id;
    end

    // Flush
    if (flush_rf_en) begin
        isdep_n[31:1] = flush_dep_rf_en[31:1];
        id_n[31:1] = flush_dep_rf[31:1];
    end
end

// commit x1
// issue x1, x1

always_comb begin
    // sr1
    rf_sr1_id = id[issue_sr1];
    // If commit and read happen in same cycle
    if (commit_rf_en && commit_rd && (commit_rd == issue_sr1)) begin
        // If the commit id equals to dependent id
        if (isdep[commit_rd] && commit_id == id[commit_rd])
            rf_sr1_rdy = 1'b1;
        else
            rf_sr1_rdy = 1'b0;
        rf_sr1_val = data_n[issue_sr1];
    end
    else begin
        rf_sr1_rdy = ~ isdep[issue_sr1];
        rf_sr1_val = data[issue_sr1];
    end
    
    // sr2
    rf_sr2_id = id[issue_sr2];
    if (commit_rf_en && commit_rd && (commit_rd == issue_sr2)) begin
        if (isdep[commit_rd] && commit_id == id[commit_rd])
            rf_sr2_rdy = 1'b1;
        else
            rf_sr2_rdy = 1'b0;
        rf_sr2_val = data_n[issue_sr2];
    end
    else begin
        rf_sr2_rdy = ~ isdep[issue_sr2];
        rf_sr2_val = data[issue_sr2];
    end
end


endmodule : regfile