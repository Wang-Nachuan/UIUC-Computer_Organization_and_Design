
module control
import rv32i_types::*; /* Import types defined in rv32i_types.sv */
(
    input clk,
    input rst,

    // From Datapath
    input rv32i_opcode opcode,
    input logic [2:0] funct3,
    input logic [6:0] funct7,
    input logic br_en,
    input logic [4:0] rs1,
    input logic [4:0] rs2,
    input logic [1:0] mem_address_10,

    // To Datapath
    output pcmux::pcmux_sel_t pcmux_sel,
    output branch_funct3_t cmpop,
    output alumux::alumux1_sel_t alumux1_sel,
    output alumux::alumux2_sel_t alumux2_sel,
    output regfilemux::regfilemux_sel_t regfilemux_sel,
    output marmux::marmux_sel_t marmux_sel,
    output cmpmux::cmpmux_sel_t cmpmux_sel,
    output alu_ops aluop,
    output logic load_pc,
    output logic load_ir,
    output logic load_regfile,
    output logic load_mar,
    output logic load_mdr,
    output logic load_data_out,

    // From Memory
    input logic mem_resp,

    // To Memory
    output logic mem_read,
    output logic mem_write,
    output logic [3:0] mem_byte_enable
);

/***************** USED BY RVFIMON --- ONLY MODIFY WHEN TOLD *****************/
logic trap;
logic [4:0] rs1_addr, rs2_addr;
logic [3:0] rmask, wmask;

branch_funct3_t branch_funct3;
store_funct3_t store_funct3;
load_funct3_t load_funct3;
arith_funct3_t arith_funct3;

assign arith_funct3 = arith_funct3_t'(funct3);
assign branch_funct3 = branch_funct3_t'(funct3);
assign load_funct3 = load_funct3_t'(funct3);
assign store_funct3 = store_funct3_t'(funct3);
assign rs1_addr = rs1;
assign rs2_addr = rs2;

always_comb
begin : trap_check
    trap = '0;
    rmask = '0;
    wmask = '0;

    case (opcode)
        op_lui, op_auipc, op_imm, op_reg, op_jal, op_jalr:;

        op_br: begin
            case (branch_funct3)
                beq, bne, blt, bge, bltu, bgeu:;
                default: trap = '1;
            endcase
        end

        op_load: begin
            case (load_funct3)
                lw: rmask = 4'b1111;
                lh, lhu: rmask = 4'b0011 << mem_address_10 /* Modify for MP1 Final */ ;
                lb, lbu: rmask = 4'b0001 << mem_address_10 /* Modify for MP1 Final */ ;
                default: trap = '1;
            endcase
        end

        op_store: begin
            case (store_funct3)
                sw: wmask = 4'b1111;
                sh: wmask = 4'b0011 << mem_address_10 /* Modify for MP1 Final */ ;
                sb: wmask = 4'b0001 << mem_address_10 /* Modify for MP1 Final */ ;
                default: trap = '1;
            endcase
        end

        default: trap = '1;
    endcase
end
/*****************************************************************************/

enum int unsigned {
    // Common
    fetch_1,
    fetch_2,
    fetch_3,
    decode,
    // Register-immediate
    imm,
    // Load
    ld_calc_addr,
    ld_1,
    ld_2,
    // Store
    st_calc_addr,
    st_1,
    st_2,
    // LUI
    lui,
    // AUIPC
    auipc,
    // Branch
    br,
    // Register-register
    rr,
    // JAL
    jal,
    // JALR
    jalr
} state, next_states;

/************************* Function Definitions *******************************/
/**
 *  You do not need to use these functions, but it can be nice to encapsulate
 *  behavior in such a way.  For example, if you use the `loadRegfile`
 *  function, then you only need to ensure that you set the load_regfile bit
 *  to 1'b1 in one place, rather than in many.
 *
 *  SystemVerilog functions must take zero "simulation time" (as opposed to 
 *  tasks).  Thus, they are generally synthesizable, and appropraite
 *  for design code.  Arguments to functions are, by default, input.  But
 *  may be passed as outputs, inouts, or by reference using the `ref` keyword.
**/

/**
 *  Rather than filling up an always_block with a whole bunch of default values,
 *  set the default values for controller output signals in this function,
 *   and then call it at the beginning of your always_comb block.
**/
function void set_defaults();
    // To Datapath
    pcmux_sel = pcmux::pc_plus4;
    cmpop = beq;
    alumux1_sel = alumux::rs1_out;
    alumux2_sel = alumux::i_imm;
    regfilemux_sel = regfilemux::alu_out;
    marmux_sel = marmux::pc_out;
    cmpmux_sel = cmpmux::rs2_out;
    aluop = alu_add;
    load_pc = 1'b0;
    load_ir = 1'b0;
    load_regfile = 1'b0;
    load_mar = 1'b0;
    load_mdr = 1'b0;
    load_data_out = 1'b0;
    // To memory
    mem_read = 1'b0;
    mem_write = 1'b0;
    mem_byte_enable = 4'b1111;
endfunction

/**
 *  Use the next several functions to set the signals needed to
 *  load various registers
**/
function void loadPC(pcmux::pcmux_sel_t sel);
    load_pc = 1'b1;
    pcmux_sel = sel;
endfunction

function void loadRegfile(regfilemux::regfilemux_sel_t sel);
    load_regfile = 1'b1;
    regfilemux_sel = sel;
endfunction

function void loadMAR(marmux::marmux_sel_t sel);
    load_mar = 1'b1;
    marmux_sel = sel;
endfunction

function void loadMDR();
    load_mdr = 1'b1;
    mem_read = 1'b1;
endfunction

function void setALU(alumux::alumux1_sel_t sel1, alumux::alumux2_sel_t sel2, logic setop, alu_ops op);
    /* Student code here */
    alumux1_sel = sel1;
    alumux2_sel = sel2;
    if (setop)
        aluop = op; // else default value
endfunction

function automatic void setCMP(cmpmux::cmpmux_sel_t sel, branch_funct3_t op);
    cmpmux_sel = sel;
    cmpop = op;
endfunction

/*****************************************************************************/

    /* Remember to deal with rst signal */

always_comb
begin : state_actions
    /* Default output assignments */
    set_defaults();
    /* Actions for each state */
    unique case (state)
        fetch_1: loadMAR(marmux::pc_out);
        fetch_2: loadMDR();
        fetch_3: load_ir = 1'b1;
        decode: ;
        // Register-immediate
        imm: begin
            loadPC(pcmux::pc_plus4);
            unique case (funct3)
                slt: begin
                    loadRegfile(regfilemux::br_en);
                    setCMP(cmpmux::i_imm, blt);
                end
                sltu: begin
                    loadRegfile(regfilemux::br_en);
                    setCMP(cmpmux::i_imm, bltu);
                end
                sr: begin
                    loadRegfile(regfilemux::alu_out);
                    if (funct7[5]) // SRAI
                        setALU(alumux::rs1_out, alumux::i_imm, 1'b1, alu_sra);
                    else // SRLI
                        setALU(alumux::rs1_out, alumux::i_imm, 1'b1, alu_srl);
                end
                default: begin
                    loadRegfile(regfilemux::alu_out);
                    setALU(alumux::rs1_out, alumux::i_imm, 1'b1, alu_ops'(funct3));
                end
            endcase
        end
        // Load
        ld_calc_addr: begin
            setALU(alumux::rs1_out, alumux::i_imm, 1'b1, alu_add);
            loadMAR(marmux::alu_out);
        end
        ld_1: loadMDR();
        ld_2: begin
            loadPC(pcmux::pc_plus4);
            unique case (funct3)
                lb: loadRegfile(regfilemux::lb);
                lh: loadRegfile(regfilemux::lh);
                lw: loadRegfile(regfilemux::lw);
                lbu: loadRegfile(regfilemux::lbu);
                lhu: loadRegfile(regfilemux::lhu);
                default: loadRegfile(regfilemux::lw);
            endcase
        end
        // Store
        st_calc_addr: begin
            setALU(alumux::rs1_out, alumux::s_imm, 1'b1, alu_add);
            loadMAR(marmux::alu_out);
            load_data_out = 1'b1;
        end
        st_1: begin
            mem_write = 1'b1;
            unique case (funct3)
                sb: mem_byte_enable = 4'b0001 << mem_address_10;
                sh: mem_byte_enable = 4'b0011 << mem_address_10;
                sw: mem_byte_enable = 4'b1111;
                default: mem_byte_enable = 4'b1111;
            endcase
        end
        st_2: loadPC(pcmux::pc_plus4);
        // LUI
        lui: begin
            loadRegfile(regfilemux::u_imm);
            loadPC(pcmux::pc_plus4);
        end
        // AUIPC
        auipc: begin
            setALU(alumux::pc_out, alumux::u_imm, 1'b1, alu_add);
            loadRegfile(regfilemux::alu_out);
            loadPC(pcmux::pc_plus4);
        end
        // Branch
        br: begin
            loadPC(pcmux::pcmux_sel_t'(br_en));
            setCMP(cmpmux::rs2_out, branch_funct3_t'(funct3));
            setALU(alumux::pc_out, alumux::b_imm, 1'b1, alu_add);
        end
        // Register-register
        rr: begin
            loadPC(pcmux::pc_plus4);
            unique case (funct3)
                slt: begin
                    setCMP(cmpmux::rs2_out, blt);
                    loadRegfile(regfilemux::br_en);
                end
                sltu: begin
                    setCMP(cmpmux::rs2_out, bltu);
                    loadRegfile(regfilemux::br_en);
                end
                sr: begin
                    loadRegfile(regfilemux::alu_out);
                    if (funct7[5]) // SRA
                        setALU(alumux::rs1_out, alumux::rs2_out, 1'b1, alu_sra);
                    else // SRL
                        setALU(alumux::rs1_out, alumux::rs2_out, 1'b1, alu_srl);
                end
                add: begin
                    loadRegfile(regfilemux::alu_out);
                    if (funct7[5]) // SUB
                        setALU(alumux::rs1_out, alumux::rs2_out, 1'b1, alu_sub);
                    else // ADD
                        setALU(alumux::rs1_out, alumux::rs2_out, 1'b1, alu_add);
                end
                default: begin
                    loadRegfile(regfilemux::alu_out);
                    setALU(alumux::rs1_out, alumux::rs2_out, 1'b1, alu_ops'(funct3));
                end
            endcase
        end
        // JAL
        jal: begin
            setALU(alumux::pc_out, alumux::j_imm, 1'b1, alu_add);
            loadPC(pcmux::alu_out);
            loadRegfile(regfilemux::pc_plus4);
        end
        // JALR
        jalr: begin
            setALU(alumux::rs1_out, alumux::i_imm, 1'b1, alu_add);
            loadPC(pcmux::alu_mod2);
            loadRegfile(regfilemux::pc_plus4);
        end
    endcase
end

always_comb
begin : next_state_logic
    next_states = state;
    unique case (state)
        fetch_1: next_states = fetch_2;
        fetch_2: if (mem_resp) next_states = fetch_3;
        fetch_3: next_states = decode;
        decode: begin
            case (opcode)
                op_lui: next_states = lui;
                op_auipc: next_states = auipc;
                op_jal: next_states = jal;
                op_jalr: next_states = jalr;
                op_br: next_states = br;
                op_load: next_states = ld_calc_addr;
                op_store: next_states = st_calc_addr;
                op_imm: next_states = imm;
                op_reg: next_states = rr;
                // op_csr: next_states = ;
                // default: next_states = fetch_1;
            endcase
        end
        // Register-immediate
        imm: next_states = fetch_1;
        // Load
        ld_calc_addr: next_states = ld_1;
        ld_1: if (mem_resp) next_states = ld_2;
        ld_2: next_states = fetch_1;
        // Store
        st_calc_addr: next_states = st_1;
        st_1: if (mem_resp) next_states = st_2;
        st_2: next_states = fetch_1;
        // LUI
        lui: next_states = fetch_1;
        // AUIPC
        auipc: next_states = fetch_1;
        // Branch
        br: next_states = fetch_1;
        // Register-register
        rr: next_states = fetch_1;
        // JAL
        jal: next_states = fetch_1;
        // JALR
        jalr: next_states = fetch_1;
    endcase
end

always_ff @(posedge clk)
begin: next_state_assignment
    if (rst)
        state <= fetch_1;
    else
        state <= next_states;
end

endmodule : control
