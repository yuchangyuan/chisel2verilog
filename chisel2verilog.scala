package chisel2verilog

import scala.reflect.runtime.{universe => ru}
import chisel3._

object run {
    def main(args: Array[String]) {
        val mirror: ru.Mirror = ru.runtimeMirror(getClass.getClassLoader)

        val classSymbol = mirror.staticClass(args(0))
        val consMethodSymbol = classSymbol.primaryConstructor.asMethod

        val classMirror = mirror.reflectClass(classSymbol)
        val consMethodMirror = classMirror.reflectConstructor(consMethodSymbol)

        circt.stage.ChiselStage.emitSystemVerilogFile(consMethodMirror.apply().asInstanceOf[RawModule], args.drop(1))
    }
}
