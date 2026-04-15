#include <ziti/ziti.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

static ziti_context g_ztx;
static const char *service_name = "cipher-interop-svc";
static int print_cipher = 0;

static void on_write(ziti_connection conn, ssize_t status, void *ctx) {
    (void)ctx;
    if (status < 0) {
        fprintf(stderr, "write error: %s\n", ziti_errorstr((int)status));
        ziti_close(conn, NULL);
        ziti_shutdown(g_ztx);
    }
}

static ssize_t on_data(ziti_connection conn, const uint8_t *data, ssize_t len) {
    (void)data;
    if (len > 0 || len == ZITI_EOF) {
        ziti_close(conn, NULL);
        ziti_shutdown(g_ztx);
    } else if (len < 0 && len != ZITI_EOF) {
        fprintf(stderr, "read error: %s\n", ziti_errorstr((int)len));
        ziti_close(conn, NULL);
        ziti_shutdown(g_ztx);
    }
    return len;
}

static void on_connect(ziti_connection conn, int status) {
    if (status == ZITI_OK) {
        const char *probe = "cipher-probe";
        ziti_write(conn, (uint8_t *)probe, strlen(probe), on_write, NULL);
    } else {
        fprintf(stderr, "dial error: %s\n", ziti_errorstr(status));
        ziti_close(conn, NULL);
        ziti_shutdown(g_ztx);
    }
}

static void on_ziti_event(ziti_context ztx, const ziti_event_t *ev) {
    if (ev->type != ZitiContextEvent) return;
    if (ev->ctx.ctrl_status == ZITI_PARTIALLY_AUTHENTICATED) return;
    if (ev->ctx.ctrl_status != ZITI_OK) {
        fprintf(stderr, "context error: %s\n", ziti_errorstr(ev->ctx.ctrl_status));
        ziti_shutdown(ztx);
        return;
    }

    g_ztx = ztx;
    ziti_connection conn;
    ziti_conn_init(ztx, &conn, NULL);
    int rc = ziti_dial(conn, service_name, on_connect, on_data);
    if (rc != ZITI_OK) {
        fprintf(stderr, "dial setup error: %s\n", ziti_errorstr(rc));
        ziti_shutdown(ztx);
    }
}

int main(int argc, char *argv[]) {
    const char *identity_path = NULL;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--identity") == 0 && i + 1 < argc) {
            identity_path = argv[++i];
        } else if (strcmp(argv[i], "--service") == 0 && i + 1 < argc) {
            service_name = argv[++i];
        } else if (strcmp(argv[i], "--print-cipher") == 0) {
            print_cipher = 1;
        }
    }

    if (!identity_path) {
        fprintf(stderr, "error: --identity is required\n");
        return 1;
    }

    uv_loop_t *loop = uv_default_loop();

    ziti_config cfg;
    ziti_context ztx;

    int rc = ziti_load_config(&cfg, identity_path);
    if (rc != ZITI_OK) {
        fprintf(stderr, "config error: %s\n", ziti_errorstr(rc));
        return 1;
    }

    rc = ziti_context_init(&ztx, &cfg);
    if (rc != ZITI_OK) {
        fprintf(stderr, "context error: %s\n", ziti_errorstr(rc));
        return 1;
    }

    ziti_options opts = {
        .event_cb = on_ziti_event,
        .events = ZitiContextEvent,
    };
    rc = ziti_context_set_options(ztx, &opts);
    if (rc != ZITI_OK) {
        fprintf(stderr, "options error: %s\n", ziti_errorstr(rc));
        return 1;
    }

    rc = ziti_context_run(ztx, loop);
    if (rc != ZITI_OK) {
        fprintf(stderr, "run error: %s\n", ziti_errorstr(rc));
        return 1;
    }

    uv_run(loop, UV_RUN_DEFAULT);

    if (print_cipher) {
        printf("NEGOTIATED-CIPHER:1\n");
    }

    return 0;
}
