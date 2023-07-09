package test

import chisel3._

class Cnt extends Module {
  override val desiredName = "cnt"

  val io = IO(new Bundle {
    val inc = Input(Bool())
    val clr = Input(Bool())
    val cnt = Output(UInt(8.W))
  })

  val cntReg = RegInit(0.U(8.W))

  when (io.inc) {
    cntReg := cntReg + 1.U
  }

  when (io.clr) {
    cntReg := 0.U
  }

  io.cnt := cntReg
}
