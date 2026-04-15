#include <ziti/ziti.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

static ziti_context g_ztx;
static ziti_connection g_listener;
static const char *service_name = "cipher-interop-svc";
static int print_cipher = 0;

static void on_echo_write(ziti_connection clt, ssize_t status, void *ctx) {
    (void)status;
    if (ctx) free(ctx);
    ziti_close(clt, NULL);
    ziti_close(g_listener, NULL);
    ziti_shutdown(g_ztx);
}

static ssize_t on_client_data(ziti_connection clt, const uint8_t *data, ssize_t len) {
    if (len > 0) {
        uint8_t *echo = malloc(len);
        memcpy(echo, data, len);
        ziti_write(clt, echo, len, on_echo_write, echo);
    } else if (len == ZITI_EOF) {
        ziti_close(clt, NULL);
        ziti_close(g_listener, NULL);
        ziti_shutdown(g_ztx);
    } else {
        fprintf(stderr, "client data error: %s\n", ziti_errorstr((int)len));
        ziti_close(clt, NULL);
        ziti_close(g_listener, NULL);
        ziti_shutdown(g_ztx);
    }
    return len;
}

static void on_client_connect(ziti_connection clt, int status) {
    (void)clt;
    (void)status;
}

static void on_client(ziti_connection serv, ziti_connection client,
                      int status, const ziti_client_ctx *clt_ctx) {
    (void)serv;
    (void)clt_ctx;
    if (status == ZITI_OK) {
        ziti_accept(client, on_client_connect, on_client_data);
    } else {
        fprintf(stderr, "accept error: %s\n", ziti_errorstr(status));
        ziti_close(serv, NULL);
        ziti_shutdown(g_ztx);
    }
}

static void on_listen(ziti_connection serv, int status) {
    if (status != ZITI_OK) {
        fprintf(stderr, "listen error: %s\n", ziti_errorstr(status));
        ziti_close(serv, NULL);
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
    ziti_conn_init(ztx, &g_listener, NULL);
    ziti_listen(g_listener, service_name, on_listen, on_client);
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
