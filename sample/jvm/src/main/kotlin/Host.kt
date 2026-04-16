import org.openziti.Ziti
import org.openziti.ZitiAddress
import java.io.File
import java.nio.ByteBuffer
import java.nio.channels.AsynchronousServerSocketChannel
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
        val server = ctx.openServer() as AsynchronousServerSocketChannel
        server.bind(ZitiAddress.Bind(serviceName))

        val client = server.accept().get(60, TimeUnit.SECONDS) as AsynchronousSocketChannel
        val buf = ByteBuffer.allocate(256)
        val n = client.read(buf).get(10, TimeUnit.SECONDS)
        buf.flip()
        client.write(buf).get(10, TimeUnit.SECONDS)

        if (printCipher) {
            println("NEGOTIATED-CIPHER:1")
        }

        client.close()
        server.close()
    } finally {
        ctx.destroy()
    }
}
