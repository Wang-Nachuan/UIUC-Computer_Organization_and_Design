module rob 
import rv32i_types::*; 
#(
    parameter size = SIZE_ROB
)
(
    input logic clk,
    input logic rst,

    // Issue instruction
    input logic issue_req,
    input logic [1:0] issue_type,
    input logic issue_isrd,         // 1-The instruction has a rd
    input logic [4:0] issue_rd,
    input logic [31:0] issue_pcnext,
    output logic rob_isfull,
    output logic [$clog2(size)-1:0] rob_id,

    // At issue stage Check whether the dependence is resolved (but not commited yet)
    input logic [$clog2(size)-1:0] rf_sr1_id,
    input logic [$clog2(size)-1:0] rf_sr2_id,
    output logic rob_sr1_rdy,
    output logic [31:0] rob_sr1_val,
    output logic rob_sr2_rdy,
    output logic [31:0] rob_sr2_val,

    // Write value
    input cdb_data cdb_data_out,

    // Commit instruction
    // Regfile
    output logic commit_rf_en,
    output logic [4:0] commit_rd,
    output logic [31:0] commit_data,
    output logic [$clog2(size)-1:0] commit_id,
    // Load/store queue
    output logic commit_lsq_en,
    output logic [$clog2(size)-1:0] commit_lsq_id,

    // Flush
    input logic br_valid,
    input logic [$clog2(size)-1:0] br_id,         // Id of br instruction
    input logic [31:0] br_addr,             // Correct address of branching
    output cdb_flush cdb_flush_in,
    output logic [31:0] flush_dep_rf_en,
    output logic [31:0][$clog2(size)-1:0] flush_dep_rf,

    // PC
    output logic [31:0] rob_pc
);

// Internal state
// Pointer
logic [$clog2(size)-1:0] p_inst_old, p_inst_old_n; 
logic [$clog2(size)-1:0] p_inst_new, p_inst_new_n;    // Point to the next available line
// Buffer
logic [size-1:0] valid, valid_n;                // 1-The line is valid
logic [size-1:0] isfinish, isfinish_n;          // 1-The instruction has finished execution
logic [size-1:0][1:0] itype, itype_n;           // Type of instruction
logic [size-1:0] isrd, isrd_n;                  // 1-The instruction will write to a register
logic [size-1:0][4:0] rd, rd_n;                 // Destination register of instruction
logic [size-1:0][31:0] data, data_n;            // The value produced by that instruction (if any)
logic [size-1:0][31:0] addr, addr_n;            // Address of the next instruction
logic [size-1:0] ls_active, ls_active_n;        // 1-The load/store instruction is activated in lsq

// Flage signals
logic flag_commit_i;                // 1-Commit in this cycle
logic flag_flush_i;                 // 1-Flush in this cycle
logic [size-1:0] flag_inrange_flush_i;    // 1-Line i is within the flush interval (and hence need to be flushed)
logic [size-1:0] flag_inrange_unflush_i;

// Other signals
logic [31:0] pc_i, pc_i_n;

assign flag_commit_i = valid[p_inst_old] & isfinish[p_inst_old];
assign flag_flush_i = br_valid & valid[br_id] & (addr[br_id] != br_addr);
assign rob_pc = pc_i;

// Update internal state (ff)
always_ff @(posedge clk) begin
    if (rst) begin
        p_inst_old <= {$clog2(size){1'b0}};
        p_inst_new <= {$clog2(size){1'b0}};
        valid <= {size{1'b0}};
        ls_active <= {size{1'b0}};
        pc_i <= 32'h60;
    end
    else begin
        p_inst_old <= p_inst_old_n;
        p_inst_new <= p_inst_new_n;
        valid <= valid_n;
        ls_active <= ls_active_n;
        pc_i <= pc_i_n;
    end

    isfinish <= isfinish_n;
    itype <= itype_n;
    isrd <= isrd_n;
    rd <= rd_n;
    data <= data_n;
    addr <= addr_n;
end

// Update internal state (comb)
always_comb begin
    /* Order of if-statements is important */
    // Default
    p_inst_old_n = p_inst_old; 
    p_inst_new_n = p_inst_new;
    valid_n = valid;
    isfinish_n = isfinish;
    itype_n = itype;
    isrd_n = isrd;
    rd_n = rd;
    data_n = data;
    addr_n = addr;
    ls_active_n = ls_active;
    pc_i_n = pc_i;

    // Commit
    if (flag_commit_i) begin
        p_inst_old_n = p_inst_old + {{($clog2(size)-1){1'b0}}, 1'b1};
        valid_n[p_inst_old] = 1'b0;
        pc_i_n = addr[p_inst_old];
    end

    // Commit load/store
    if (valid[p_inst_old] && (itype[p_inst_old] == itype_ls) && (~ ls_active[p_inst_old])) begin
        ls_active_n[p_inst_old] = 1'b1;
    end
    
    // Issue
    if (issue_req && (~flag_flush_i)) begin
        p_inst_new_n = p_inst_new + {{($clog2(size)-1){1'b0}}, 1'b1};
        // Set flage bits
        valid_n[p_inst_new] = 1'b1;
        isfinish_n[p_inst_new] = 1'b0;
        ls_active_n[p_inst_new] = 1'b0;
        // Store data
        itype_n[p_inst_new] = issue_type;
        isrd_n[p_inst_new] = issue_isrd;
        rd_n[p_inst_new] = issue_rd;
        addr_n[p_inst_new] = issue_pcnext;
    end

    // Write
    if (cdb_data_out.valid) begin
        data_n[cdb_data_out.id] = cdb_data_out.data;
        isfinish_n[cdb_data_out.id] = 1'b1;
    end

    // Flush
    if (flag_flush_i) begin
        p_inst_new_n = br_id + {{($clog2(size)-1){1'b0}}, 1'b1};
        addr_n[br_id] = br_addr;
        for (int i=0; i<size; i++) begin
            if (flag_inrange_flush_i[i]) begin
                valid_n[i] = 1'b0;
            end
        end
    end
end

// Generate output
always_comb begin
    // Flush
    // for (int i=0; i<size; i++) begin
    //     if (br_id <= p_inst_new)
    //         flag_inrange_flush_i[i] = (i[$clog2(size)-1:0] > br_id) && (i[$clog2(size)-1:0] < p_inst_new) ? 1'b1: 1'b0;
    //     else 
    //         flag_inrange_flush_i[i] = (i[$clog2(size)-1:0] > br_id) || (i[$clog2(size)-1:0] < p_inst_new) ? 1'b1: 1'b0;
    // end
    for (int i=0; i<size; i++) begin
        if (br_id >= p_inst_old)
            flag_inrange_unflush_i[i] = (i[$clog2(size)-1:0] >= p_inst_old) && (i[$clog2(size)-1:0] <= br_id) ? 1'b1: 1'b0;
        else 
            flag_inrange_unflush_i[i] = (i[$clog2(size)-1:0] >= p_inst_old) || (i[$clog2(size)-1:0] <= br_id) ? 1'b1: 1'b0;
    end
    flag_inrange_flush_i = ~ flag_inrange_unflush_i;
    cdb_flush_in.en = flag_flush_i;
    cdb_flush_in.en_id = flag_inrange_flush_i;

    // Update regfile dependence
    for (int i=0; i<32; i++) begin
        flush_dep_rf_en[i] = 1'b0;      // 1-Has dependency
        flush_dep_rf[i] = {$clog2(size){1'b0}};     // Id of dependent instruction
        for (int j=0; j<size; j++) begin
            // Search in all unflushed instructions
            if ((flag_inrange_unflush_i[br_id - j[$clog2(size)-1:0]]) && valid[br_id - j[$clog2(size)-1:0]]) begin
                // If the instruction is commited in this cycle, skip it
                if (isrd[br_id - j[$clog2(size)-1:0]] && (rd[br_id - j[$clog2(size)-1:0]] == i[4:0])
                    && ~(flag_commit_i && p_inst_old == (br_id - j[$clog2(size)-1:0]))) begin
                    flush_dep_rf_en[i] = 1'b1;
                    flush_dep_rf[i] = br_id - j[$clog2(size)-1:0];
                    break;
                end
            end
        end
    end

    // Issue
    rob_isfull = (& valid) & (~ flag_commit_i);     // Still can issue if one line can commit
    rob_id = p_inst_new;

    // Commit load/store
    commit_lsq_en = 1'b0;
    commit_lsq_id = {$clog2(size){1'b0}};
    if (valid[p_inst_old] && (itype[p_inst_old] == itype_ls) && (~ ls_active[p_inst_old])) begin
        commit_lsq_en = 1'b1; 
        commit_lsq_id = p_inst_old;
    end

    // Commit regfile
    commit_rf_en = isrd[p_inst_old] ? flag_commit_i : 1'b0;
    commit_rd = rd[p_inst_old];
    commit_data = data[p_inst_old];
    commit_id = p_inst_old;

    // At issue stage Check whether the dependence is resolved (but not commited yet)
    rob_sr1_rdy = isfinish[rf_sr1_id];
    rob_sr1_val = data[rf_sr1_id];
    rob_sr2_rdy = isfinish[rf_sr2_id];
    rob_sr2_val = data[rf_sr2_id];
end

endmodule : rob