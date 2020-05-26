//
// Example 1
// Synchronous RPC
//
void fn () {
  get_args a; a.key = ...;
  get_result r;
  clnt_stat stat = call (BLOCK_GET, &a, &r); // blocks
  if (stat) {
    handle_error ();
    return;
  }
  printf ("%s\n", r->value);
  do_something_else ();
}

//
// Example 2
// What call does (conceptual "pseudocode")
//
int serverfd;
int
call (int proc, void *args, void *res) {
  rpc_msg m;
  m.xid = random ();
  m.call.prog = proc;
  m.call.args = args;
  str out = xdr2str (m); // libarpc marshalling code
  write (serverfd, out.cstr (), out.len ());

  char reply[1024]; // Block waiting for reply
  int len = read (serverfd, reply, sizeof (reply));
  rpc_msg r;
  if (str2xdr (r, str (reply, len))) { // unmarshalling
    assert (r.xid == m.xid);
    memcpy (r, r.resp.res, sizeof (r));
    return RPC_SUCCESS;
  }
  return RPC_FAILED;
}

//
// Example 3
// Asynchronous RPC
//
ptr<aclnt> c;
void fn () {
  get_args a;
  a.key = key
  ptr<get_result> r = New refcounted<get_result> ();
  c->call (BLOCK_GET, &a, r, wrap (use_results, key, r));
}

void use_results (str key, ptr<get_results> r, clnt_stat stat) {
  if (stat) {
    handle_error ();
  }
  printf ("%s\n", r->value);
  do_something_else ();
}

//
// Example 4
// Using asynchronous RPCs in context
//
void
blockdbc::get (str key, callback<void, bool, str>::ref cb)
{
  get_args a;
  a.key = key
  get_result *r = New refcounted<get_result> ();
  c->call (BLOCK_GET, &a, r, wrap (this, &get_helper, cb, r));
}
void
blockdbc::get_helper (callback<void, bool, str>::ref cb,
  ptr<get_results> r,
  clnt_stat stat)
{
  if (stat) {
    cb (false, "");
  } else {
    // XXX more or less
    cb (true, r->value);
  }
}

typedef callback<void>::ref cbv;
void fn ()
{
  db = New blockdbc (...);
  cb = wrap (do_something_else);
  db->get (key, wrap (use_results, cb, key));
}
void use_results (cbv cb, str key, bool ok, str data)
{
  assert (ok);
  warn << "key: " << key << "\n";
  warn << "data: " << data << "\n";
  cb ();
}

//
// Example 5
// Simple RPC dispatcher
//
int main ()
{
  int serverfd = setup (port);
  ptr<axprt> ax = axprt::alloc (serverfd);
  BS *bs = New BS ();
  ptr<asrv> srv = asrv::alloc (ax, block_prog_1, wrap (&bs::dispatch, bs));
  amain ();
}
void BS::dispatch(BS *bs, svccb *sbp)
{
  switch(sbp->proc()){
  case BLOCK_GET:
    {
      gets++;
      get_args *a = sbp->Xtmpl getarg<get_args>();
      bs->db->get(str(a->key.base(), a->key.size()),
                  wrap(bs, &BS::get_cb, sbp));
    }
    break;
  case BLOCK_PUT:
    // ...
    break;
  case BLOCK_REMOVE:
    // ...
    break;
  default:
    fprintf(stderr, "blockdbd: unknown RPC %d\n", sbp->proc());
    sbp->reject(PROC_UNAVAIL);
    break;
  }
}
void BS::get_cb(svccb *sbp, bool ok, str value)
{
  get_result *r = sbp->Xtmpl getres<get_result>();
  r->ok = ok;
  r->value = value;
  sbp->reply(r);
}

// 
// Example 6: NFS create
//
void fs::nfs3_create (nfscall *nc)
{
  nfs_fh3 dir = nc->getarg ...;
  get_dir_block (dir, wrap (this, &fs::nfs3_create_cb1, nc));
}
void fs::nfs3_create_cb1 (nfscall *nc, bool ok, str dirblock)
{
  str name = nc->getarg ...;
  nfs_fh3 nfh;
  new_fh (&nfh); 
  // update dirblock
  put_dir_block (dir, dirblock, wrap (this, &fs::nfs3_create_cb2, nc, nfh));
}
void fs::nfs3_create_cb2 (nfscall *nc, nfs_fh3 nfh, bool ok)
{
  put_fh (nfh, wrap (this, &fs::nfs3_create_cb3, nc, nfh));
}
void fs::nfs3_create_cb3 (nfscall *nc, nfs_fh3 nfh, bool ok)
{
  diropres3 *res = nc->getres<diropres3> ();
  // fillout res
  nc->reply (res);
}

//
// Example 7a: synchronous
//
void fn ()
{
  // ...
  for (i = 0; i < nblocks; i++) {
    str block = get (str (i));
    if (block == "XXX") {
      printf ("found!");
      break;
    }
  }
  do_something_else ();
}

//
// Example 7b: serially asynchronous
//
void fn ()
{
  cbv cb = wrap (do_something_else);
  db->get (str (i), wrap (helper, cb, i, nblocks));
}

void helper (cbv cb, int i, int nblocks, bool ok, str block)
{
  if (block == "XXX") {
    printf ("found!");
    cb ();
  } else {
    if (i + 1 < nblocks) {
      // tail "recurse"
      db->get (str (i+1), wrap (helper, cb, i+1, nblocks));
    } else {
      cb ();
    }
  }
}

//
// Example 7c: parallelism (with "bug")
// 
void fn ()
{
  cbv cb = wrap (do_something_else);
  for (i = 0; i < nblocks; i++) {
    db->get (str (i), wrap (helper, cb));
  }
}

void helper (cbv cb, bool ok, str block)
{
  if (block == "XXX") {
    printf ("found!");
    cb ();
  }
}

//
// Example 7d: parallelism with shared state
//
void fn ()
{
  cbv cb = wrap (do_something_else);
  ptr<bool> done = New refcounted<bool> (false);
  for (i = 0; i < nblocks; i++) {
    db->get (str (i), wrap (helper, cb, done));
  }
}

void helper (cbv cb, ptr<bool> done, bool ok, str block)
{
  if (!*done && block == "XXX" && ) {
    printf ("found!");
    *done = true;
    cb ();
  }
}
