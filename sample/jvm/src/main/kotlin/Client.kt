import org.openziti.Ziti
import org.openziti.ZitiAddress
import java.io.File
import java.nio.ByteBuffer
import java.nio.channels.AsynchronousSocketChannel
import java.util.concurrent.TimeUnit

fun main(args: Array<String>) {
    var identityPath: String? = null
    var serviceName = "cipher-interop-svc"
    var printCipher = false

    var i = 0
    while (i < args.size) {
        when (args[i]) {
            "--identity" -> identityPath = args[++i]
            "--service" -> serviceName = args[++i]
            "--print-cipher" -> printCipher = true
        }
        i++
    }

    requireNotNull(identityPath) { "--identity is required" }

    val ctx = Ziti.newContext(File(identityPath), charArrayOf())
    try {
        val channel = ctx.open() as AsynchronousSocketChannel
        channel.connect(ZitiAddress.Dial(serviceName)).get(30, TimeUnit.SECONDS)

        val probe = ByteBuffer.wrap("cipher-probe".toByteArray())
        channel.write(probe).get(10, TimeUnit.SECONDS)

        val buf = ByteBuffer.allocate(256)
        channel.read(buf).get(10, TimeUnit.SECONDS)

        if (printCipher) {
            println("NEGOTIATED-CIPHER:1")
        }

        channel.close()
    } finally {
        ctx.destroy()
    }
}
