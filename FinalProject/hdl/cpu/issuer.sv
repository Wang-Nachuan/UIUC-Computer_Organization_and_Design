module issuer
import rv32i_types::*;    
#(  parameter size_br_his = SIZE_GLOBAL
)  
(          
    // to and from inst queue
    output logic issue_req,   //combinational, logic issue_req
    input rv32i_word iq_inst,
    input rv32i_word iq_pc,
    input rv32i_word iq_pc_next,
    input logic iq_rvalid, //
    input logic [size_br_his-1:0] iq_br_history,
    // input logic is_empty_q,

    // to and from RS1, regfile connected to CPU, only need sel signal 
    input logic rs1_isfull,
    output logic issue_en_rs1,
    output inst_type issue_type,  // one of four types
    output logic issue_isrd,
    output logic [4:0] issue_rd,
    output logic [4:0] issue_sr1,
    output logic [4:0] issue_sr2,
    output rv32i_word issue_pc,       
    output rv32i_word issue_pcnext,   // ROB 
    output rv32i_word issue_i_imm,
    output rv32i_word issue_s_imm,
    output rv32i_word issue_b_imm,
    output rv32i_word issue_u_imm,
    output rv32i_word issue_j_imm,
    output logic [2:0] issue_rs1_opr1_sel,
    output logic [2:0] issue_rs1_opr2_sel,
    output alu_opc issue_opc_rs1,

    // output logic issue_br_jumped,
    // output inst_type issue_type,
    input logic rs2_isfull,
    output logic issue_en_rs2,
    output logic [2:0] issue_rs2_opr1_sel,
    output logic [2:0] issue_rs2_opr2_sel,
    output logic [2:0] issue_rs2_opr3_sel,
    output br_opc issue_opc_rs2,

    input logic lsq_isfull,
    output logic issue_en_lsq,
    output logic [2:0] issue_lsq_opr1_sel,
    output logic [2:0] issue_lsq_opr2_sel,
    output logic [2:0] issue_lsq_opr3_sel,
    output ls_opc issue_opc_lsq,

    // Flush
    input logic flush,
    output logic [size_br_his-1:0] issue_br_history,

    // to and from ROB 
    // output logic issue_req, //set high when requested  to ROB, regfile, reservation station

    input logic rob_isfull

    // to and from reservation station

);
logic [2:0] funct3;
logic [6:0] funct7;
rv32i_opcode opcode;
logic [31:0] i_imm;
logic [31:0] s_imm;
logic [31:0] b_imm;
logic [31:0] u_imm;
logic [31:0] j_imm;
rv32i_reg rd;
branch_funct3_t branch_funct3;
store_funct3_t  store_funct3;
load_funct3_t   load_funct3;
arith_funct3_t  arith_funct3;

logic trap;     // For RVFI monitor only
assign issue_br_history = iq_br_history;
assign issue_pc = iq_pc;
assign issue_pcnext = iq_pc_next;
assign funct3 = iq_inst[14:12];
assign funct7 = iq_inst[31:25];
assign opcode = rv32i_opcode'(iq_inst[6:0]);
assign issue_i_imm = {{21{iq_inst[31]}}, iq_inst[30:20]};
assign issue_s_imm = {{21{iq_inst[31]}}, iq_inst[30:25], iq_inst[11:7]};
assign issue_b_imm = {{20{iq_inst[31]}}, iq_inst[7], iq_inst[30:25], iq_inst[11:8], 1'b0};
assign issue_u_imm = {iq_inst[31:12], 12'h000};
assign issue_j_imm = {{12{iq_inst[31]}}, iq_inst[19:12], iq_inst[20], iq_inst[30:21], 1'b0};
assign issue_sr1 = iq_inst[19:15];
assign issue_sr2 = iq_inst[24:20];
assign issue_rd = iq_inst[11:7];



assign arith_funct3 = arith_funct3_t'(funct3);
assign branch_funct3 = branch_funct3_t'(funct3);
assign load_funct3 = load_funct3_t'(funct3);
assign store_funct3 = store_funct3_t'(funct3);




//set issue_req, to read data from instruction Q 
//set issue_type
always_comb begin : read_logic
    issue_req = 1'b0;
    issue_type = itype_alu;
    trap = 1'b0;
    if(~rob_isfull && iq_rvalid && ~flush) begin
        case(opcode)
            op_imm: begin
                case (arith_funct3)
                    add, sll, axor, sr, aor, aand, slt, sltu: begin
                        if(~rs1_isfull) begin
                            issue_isrd = 1'b1;
                            issue_req = 1'b1;
                            issue_type = itype_alu;
                        end
                    end
                    default: trap = 1'b1;
                endcase

                case (arith_funct3)
                    add: issue_opc_rs1 = alu_add;
                    sll: issue_opc_rs1 = alu_sll;
                    slt: issue_opc_rs1 = alu_slt;
                    sltu: issue_opc_rs1 = alu_sltu;
                    axor: issue_opc_rs1 = alu_xor;
                    sr: begin
                        if(funct7[5]) begin
                            issue_opc_rs1 = alu_sra;
                        end
                        else begin
                            issue_opc_rs1 = alu_srl;
                        end
                    end
                    aand: issue_opc_rs1 = alu_and;
                    aor: issue_opc_rs1 = alu_or;
                    default: trap = 1'b1;
                endcase
            end
            op_reg: begin
                case (arith_funct3)
                    sr, add, sll, axor, aor, aand,slt, sltu: begin
                        if(~rs1_isfull) begin
                            issue_isrd = 1'b1;
                            issue_req = 1'b1;
                            issue_type = itype_alu;
                        end
                    end
                    default: trap = 1'b1;
                endcase

                case (arith_funct3)
                    add: begin
                        if(funct7[5]) begin
                            issue_opc_rs1 = alu_sub;
                        end
                        else begin
                            issue_opc_rs1 = alu_add;
                        end
                    end
                    sll: issue_opc_rs1 = alu_sll;
                    slt: issue_opc_rs1 = alu_slt;
                    sltu: issue_opc_rs1 = alu_sltu;
                    axor: issue_opc_rs1 = alu_xor;
                    sr: begin
                        if(funct7[5]) begin
                            issue_opc_rs1 = alu_sra;
                        end
                        else begin
                            issue_opc_rs1 = alu_srl;
                        end
                    end
                    aand: issue_opc_rs1 = alu_and;
                    aor: issue_opc_rs1 = alu_or;
                    default: trap = 1'b1;
                endcase 
                
            end
            op_lui,op_auipc: begin  
                if(~rs1_isfull) begin
                    issue_isrd = 1'b1;
                    issue_req = 1'b1;
                    issue_type = itype_alu;
                end
                case(opcode)
                    op_lui:issue_opc_rs1 = alu_lui;
                    op_auipc:issue_opc_rs1 = alu_auipc;
                    default: trap = 1'b1;
                endcase
            end
            op_br: begin
                if(~rs2_isfull) begin
                    issue_isrd = 1'b0;
                    issue_req = 1'b1;
                    issue_type = itype_br;
                end   
                case(branch_funct3) 
                    beq: issue_opc_rs2 = br_beq;
                    bne: issue_opc_rs2 = br_bne;
                    blt: issue_opc_rs2 = br_blt;
                    bge: issue_opc_rs2 = br_bge;
                    bltu: issue_opc_rs2 = br_bltu;
                    bgeu: issue_opc_rs2 = br_bgeu;
                    default: trap = 1'b1;
                endcase
            end
            op_jal,op_jalr: begin
                if(~rs2_isfull) begin
                    issue_isrd = 1'b1;
                    issue_req = 1'b1;
                    issue_type = itype_br;
                end 
                case(opcode)
                    op_jal: issue_opc_rs2 = br_jal;
                    op_jalr: issue_opc_rs2 = br_jalr;
                    default: trap = 1'b1;
                endcase
            end
            op_load: begin
                if(~lsq_isfull) begin
                    issue_isrd = 1'b1;
                    issue_req = 1'b1;
                    issue_type = itype_ls;
                end   
                case(load_funct3) 
                    lb:issue_opc_lsq = ls_lb;
                    lh:issue_opc_lsq = ls_lh;
                    lw:issue_opc_lsq = ls_lw;
                    lbu:issue_opc_lsq = ls_lbu;
                    lhu:issue_opc_lsq = ls_lhu;
                    default: trap = 1'b1;
                endcase                       
            end
            op_store: begin
                if(~lsq_isfull) begin
                    issue_isrd = 1'b0;
                    issue_req = 1'b1;
                    issue_type = itype_ls;
                end
                case(store_funct3)  
                    sb:issue_opc_lsq = ls_sb;
                    sh:issue_opc_lsq = ls_sh;
                    sw:issue_opc_lsq = ls_sw;
                    default: trap = 1'b1;
                endcase
            end                   
            default: trap = 1'b1;
        endcase
    end
end : read_logic


// issue_en rob and rs1, according to iq_rvalid.
always_comb begin : issue_logic
    issue_en_rs1 = 1'b0;
    issue_en_rs2 = 1'b0;
    issue_en_lsq = 1'b0;
    issue_rs1_opr1_sel = 3'b0;
    issue_rs1_opr2_sel = 3'b0;
    issue_rs2_opr1_sel = 3'b0;
    issue_rs2_opr2_sel = 3'b0;
    issue_rs2_opr3_sel = 3'b0;
    issue_lsq_opr1_sel = 3'b0;
    issue_lsq_opr2_sel = 3'b0;
    issue_lsq_opr3_sel = 3'b0;

    if (~rob_isfull && iq_rvalid && ~flush) begin
        case(opcode) 
            op_imm: begin
                case (arith_funct3)
                    add, sll, axor, sr, aor, aand, slt, sltu: begin
                        if(~rs1_isfull) begin
                            issue_en_rs1 = 1'b1;
                            issue_rs1_opr1_sel = rsoprmux::sr;
                            issue_rs1_opr2_sel = rsoprmux::i_imm;
                        end
                    end
                    default: ;
                endcase
            end
            op_reg: begin
                case (arith_funct3)
                    add, sll, axor, sr, aor, aand, slt, sltu: begin
                        if(~rs1_isfull) begin
                            issue_en_rs1 = 1'b1;
                            issue_rs1_opr1_sel = rsoprmux::sr;
                            issue_rs1_opr2_sel = rsoprmux::sr;
                        end
                    end
                endcase
            end
            op_lui:begin  // u_imm in opr2 
                if(~rs1_isfull) begin
                    issue_en_rs1 = 1'b1;
                    issue_rs1_opr1_sel = rsoprmux::none;
                    issue_rs1_opr2_sel = rsoprmux::u_imm;
                end
            end
            op_auipc: begin
                if(~rs1_isfull) begin
                    issue_en_rs1 = 1'b1;
                    issue_rs1_opr1_sel = rsoprmux::pc;
                    issue_rs1_opr2_sel = rsoprmux::u_imm;
                end
            end
            op_br: begin // not sure
                if(~rs2_isfull) begin
                    issue_en_rs2 = 1'b1;
                    issue_rs2_opr1_sel = rsoprmux::sr;  // rs1
                    issue_rs2_opr2_sel = rsoprmux::sr;  // rs2
                    issue_rs2_opr3_sel = rsoprmux::b_imm;   // offset
                end
            end
            op_jal: begin
                if(~rs2_isfull) begin
                    issue_en_rs2 = 1'b1;
                    issue_rs2_opr1_sel = rsoprmux::pc;
                    issue_rs2_opr2_sel = rsoprmux::none;
                    issue_rs2_opr3_sel = rsoprmux::j_imm;
                end
            end
            op_jalr: begin
                if(~rs2_isfull) begin
                    issue_en_rs2 = 1'b1;
                    issue_rs2_opr1_sel = rsoprmux::sr;
                    issue_rs2_opr2_sel = rsoprmux::none;
                    issue_rs2_opr3_sel = rsoprmux::i_imm;
                end
            end
            op_load: begin
                if(~lsq_isfull) begin
                    issue_en_lsq = 1'b1;
                    issue_lsq_opr1_sel = rsoprmux::sr;  // rs1 (base)
                    issue_lsq_opr2_sel = rsoprmux::none;
                    issue_lsq_opr3_sel = rsoprmux::i_imm;   // offset 
                end                    
            end
            op_store: begin // s_imm
                if(~lsq_isfull) begin
                    issue_en_lsq = 1'b1;
                    issue_lsq_opr1_sel = rsoprmux::sr;  // rs1 (base)
                    issue_lsq_opr2_sel = rsoprmux::sr;  // rs2 (src)
                    issue_lsq_opr3_sel = rsoprmux::s_imm;   // offset
                end  
            end
            default: ;
        endcase

    end

end:issue_logic


endmodule : issuer