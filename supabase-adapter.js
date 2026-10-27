// Verbindt de stocktelling-app met Supabase (aanmelden + gedeelde opslag).
(function(){
var sb=supabase.createClient(SUPABASE_URL,SUPABASE_ANON_KEY),me=null,editor=false,ok,ready=new Promise(function(r){ok=r});
function err(r){if(r.error)throw r.error;return r}
function P(p){return p.split("/")}
function rows(path){
var p=P(path);
if(p[0]==="locks")return sb.from("locks").select("hotel_id,month,closed").then(err).then(function(r){return r.data.map(function(x){return{id:x.hotel_id+"_"+x.month,d:{closed:x.closed}}})});
if(p.length===1)return sb.from("hotels").select("id,name").then(err).then(function(r){return r.data.map(function(x){return{id:x.id,d:{name:x.name}}})});
return sb.from("hotel_months").select("month,data").eq("hotel_id",p[1]).then(err).then(function(r){return r.data.map(function(x){return{id:x.month,d:x.data}})});
}
function snap(l){return{empty:!l.length,metadata:{fromCache:false},docs:l.map(function(x){return{id:x.id,exists:true,data:function(){return x.d}}})}}
function table(path){var p=P(path);return p[0]==="locks"?"locks":p.length===1?"hotels":"hotel_months"}
var db={
collection:function(path){return{
get:function(){return rows(path).then(snap)},
onSnapshot:function(cb,eb){
var live=true;
function load(){rows(path).then(function(l){if(live)cb(snap(l))},function(e){if(eb)eb(e)})}
load();
var ch=sb.channel("c"+Math.random().toString(36).slice(2)).on("postgres_changes",{event:"*",schema:"public",table:table(path)},load).subscribe();
return function(){live=false;sb.removeChannel(ch)};
}}},
doc:function(path){var p=P(path);return{set:function(d){
var q;
if(p[0]==="hotels"&&p.length===2)q=sb.from("hotels").upsert({id:p[1],name:d.name});
else if(p[0]==="hotels")q=sb.from("hotel_months").upsert({hotel_id:p[1],month:p[3],data:d});
else{var i=p[1].lastIndexOf("_");q=sb.from("locks").upsert({hotel_id:p[1].slice(0,i),month:p[1].slice(i+1),closed:!!d.closed})}
return q.then(err);
},delete:function(){
if(p[0]==="hotels"&&p.length===4)return sb.from("hotel_months").delete().eq("hotel_id",p[1]).eq("month",p[3]).then(err);
return Promise.reject({code:"invalid_argument",message:"niet ondersteund"});
}}}
};
var user={can:function(){return Promise.resolve(true)},canEdit:function(){return Promise.resolve(editor)},id:function(){return Promise.resolve(me.id)}};
var dls={save:function(o){var a=document.createElement("a");a.href=URL.createObjectURL(o.data);a.download=o.filename;document.body.appendChild(a);a.click();a.remove();return Promise.resolve()}};
window.claude={use:function(n){return ready.then(function(){return n==="db"?db:n==="user"?user:n==="downloads"?dls:null})}};
function $(i){return document.getElementById(i)}
function start(session){
me=session.user;
sb.from("editors").select("user_id").eq("user_id",me.id).then(function(r){editor=!!(r.data&&r.data.length);$("login").hidden=true;$("login").style.display="none";ok()});
}
sb.auth.getSession().then(function(r){if(r.data&&r.data.session)start(r.data.session)});
function login(){
sb.auth.signInWithPassword({email:$("le").value.trim(),password:$("lp").value}).then(function(r){
if(r.error||!r.data.session){$("lm").textContent="Aanmelden mislukt";return}
start(r.data.session);
});
}
$("li").onclick=login;
$("lp").addEventListener("keydown",function(e){if(e.key==="Enter")login()});
$("so").onclick=function(){sb.auth.signOut().then(function(){location.reload()})};
})();
