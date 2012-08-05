#include "async.h"
#include "tame.h"
#include <stdlib.h>
#include <sstream>
#include <string>

using namespace std;

//-----------------------------------------------------------------------------

class http_pipe_t {
public:

    http_pipe_t() { }
    http_pipe_t(int fd) { init(fd); }

    void init(int fd) { m_fd = fd; }
    void write_packet(str packet, evv_t::ptr ev = NULL, CLOSURE);
    void read_packet(evs_t ev, CLOSURE);

    typedef event<str, int>::ref ev_read_t;

protected:

    void do_read(int fd, ev_read_t done_cb);
    void do_write(int fd, strbuf s, evv_t done_c);

    int m_fd;
};

//-----------------------------------------------------------------------------

void http_pipe_t::do_write(int fd, strbuf s, evv_t done_cb) {
    s.tosuio()->output(fd);
    if (s.tosuio()->resid())
        return;

    fdcb(fd, selwrite, NULL);
    done_cb->trigger();
}

//-----------------------------------------------------------------------------

void http_pipe_t::do_read(int fd, ev_read_t done_cb) {
    strbuf s;
    int n = s.tosuio()->input(fd);
    
    done_cb->trigger(str(s), n);
}

//-----------------------------------------------------------------------------

tamed void 
http_pipe_t::write_packet(str packet, evv_t::ptr ev) {

    twait {
        fdcb(m_fd, selwrite, 
             wrap(this, &http_pipe_t::do_write, m_fd, packet, mkevent()));
    }

    if (ev) ev->trigger();
}

//-----------------------------------------------------------------------------

tamed void
http_pipe_t::read_packet(evs_t ev) {
    tvars {
        strbuf s;
        int len;
        http_pipe_t::ev_read_t::ptr sev;
        rendezvous_t<bool> rv (__FILE__, __LINE__);
        bool inpkt;
        str dat;
        str req;
    }

    sev = mkevent(rv, true, dat, len);
    sev->set_reuse(true);
    fdcb(m_fd, selread, wrap(this, &http_pipe_t::do_read, m_fd, sev));
    while (true) {
        twait(rv, inpkt);
        if (!inpkt || len < 0)
            break;

        s << dat;
        req = str(s);

        if (req.len() > 4 && substr(req, req.len()-4, 4) == "\r\n\r\n") break;
    }

    sev->finish();
    fdcb(m_fd, selread, NULL);
    ev->trigger(str(s));
}

//-----------------------------------------------------------------------------

class http_client_t {
public:

    void serve(int fd, CLOSURE);

protected:

    str gen_error();
    void proxy_request(str req, evs_t ev, CLOSURE);
    str get_host(str req);
};

//-----------------------------------------------------------------------------

tamed void
http_client_t::serve(int fd) {

    tvars {
        http_pipe_t pipe;
        str req;
        str resp("mike\r\n");
    }

    pipe.init(fd);
    twait { pipe.read_packet(mkevent(req)); }
    twait { proxy_request(req, mkevent(resp)); }
    twait { pipe.write_packet(resp, mkevent()); }

    close(fd);
}

//-----------------------------------------------------------------------------

str http_client_t::get_host(str req) {

    string sline;
    istringstream iss(string(req.cstr()));
    while (getline(iss, sline, '\n')) {
        str line = str(sline.c_str());
        if (line.len() >= 5 && substr(line, 0, 5) == "Host:") {
            const char* colon = strrchr(line.cstr(), ':');
            str host = str(colon + 2);
            host = substr(host, 0, host.len()-1);
            return host;
        }
    }
    return "";
}

//-----------------------------------------------------------------------------

tamed void
http_client_t::proxy_request(str req, evs_t ev) {
    
    tvars {
        int conn(0);
        http_pipe_t client;
        str resp;
        str host;
    }

    host = get_host(req);
    twait { tcpconnect(host, 80, mkevent(conn)); }
    if (conn < 0) {
        warn << "FAIL: tcpconnect() to: " << host << " conn: " << conn << "\n";
        resp = gen_error(); 
    } else {
        client.init(conn);
        twait { client.write_packet(req, mkevent()); }
        twait { client.read_packet(mkevent(resp)); }
    }

    ev->trigger(resp);
}

//-----------------------------------------------------------------------------

str http_client_t::gen_error() {
    strbuf err;
    err << "HTTP/1.0 500 Internal Server Error\n";
    err << "\r\n";
    return str(err);
}   

//-----------------------------------------------------------------------------

void proxy_accept(int fd) {
    sockaddr_in sin;
    socklen_t sinlen = sizeof (sockaddr_in);
    bzero (&sin, sinlen);
    int cfd = accept (fd, reinterpret_cast<sockaddr *> (&sin), &sinlen);
    make_async(cfd);

    (New http_client_t())->serve(cfd);
}

int main() {

    int fd = inetsocket(SOCK_STREAM, 8080, INADDR_ANY);
    make_async(fd);
    listen(fd, 5);
    fdcb(fd, selread, wrap(proxy_accept, fd));

    amain();
    return 0;
}
