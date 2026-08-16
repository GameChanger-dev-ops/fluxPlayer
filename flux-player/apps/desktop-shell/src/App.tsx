import{useEffect,useRef,useState}from'react';import{invoke}from'@tauri-apps/api/core';import{open}from'@tauri-apps/plugin-dialog';import type{Media}from'./types';

const fmt=(n:number)=>{if(!n)return'0:00';const m=Math.floor(n/60),s=Math.floor(n%60).toString().padStart(2,'0');return`${m}:${s}`};
const asset=(p:string)=>p.startsWith('file://')?p:`asset://${p.replaceAll('\\','/')}`;

export default function App(){
const[media,setMedia]=useState<Media[]>([]),[selected,setSelected]=useState<Media|null>(null),
[query,setQuery]=useState(''),[busy,setBusy]=useState(false),[profile,setProfile]=useState('Main profile'),video=useRef<HTMLVideoElement>(null);
const refresh=async()=>setMedia(await invoke<Media[]>('media_list'));
useEffect(()=>{refresh()},[]);
const scan=async()=>{const folder=await invoke<string|null>('choose_folder');if(!folder)return;setBusy(true);try{await invoke('scan_folder',{path:folder});await refresh()}finally{setBusy(false)}};
const play=(m:Media)=>{setSelected(m)};
useEffect(()=>{const v=video.current;if(!v||!selected)return;const onMeta=()=>
{if(selected.position>0&&selected.position<v.duration-5)v.currentTime=selected.position};const save=
()=>invoke('save_progress',{id:selected.id,position:v.currentTime,duration:v.duration}).catch(()=>
{});v.addEventListener('loadedmetadata',onMeta);v.addEventListener('pause',save);v.addEventListener('ended',save);return(
)=>
{v.removeEventListener('loadedmetadata',onMeta);v.removeEventListener('pause',save);v.removeEventListener('ended',save);save()}},[selected]);
const filtered=media.filter(m=>m.title.toLowerCase().includes(query.toLowerCase()));
return <div className="app"><aside><div className="logo">Flux <i>Player</i></div><div className="profile">● {profile}
</div><nav><button className="nav on">⌂ Home</button><button className="nav">▣ Movies</button><button
className="nav">▤ Shows</button><button className="nav">✦ Anime</button><button className="nav">♡ Favorites</button>
</nav><div className="sidebottom"><button className="nav">⚙ Settings</button><span>Phase 1 vertical slice</span></div>
</aside><main><header><div><p className="kicker">Local-first entertainment</p><h1>Your library</h1></div><div
className="actions"><input value={query} onChange={e=>setQuery(e.target.value)} placeholder="Search library"/><button
onClick={scan} disabled={busy}>{busy?'Scanning…':'Add media folder'}</button></div></header><section className="hero">
<div><p className="kicker">Welcome back, {profile}</p><h2>{media.length?`${media.length} titles ready`:'Your library starts here'}</h2><p>{media.length?'Pick up where you left off, or browse your local collection.':'Add a folder to scan your movies, shows, and anime. Flux works offline.'}</p><button className="primary" onClick={scan} disabled={busy}>
{busy?'Scanning…':'Add your first folder'}</button></div><div className="mark">F</div></section><section
className="sectionhead"><h2>All media</h2><span>{filtered.length} items</span></section>{!filtered.length?<div
className="empty"><b>No media yet.</b><span>Choose a local folder and Flux will index supported video files.</span>
</div>:<div className="grid">{filtered.map(m=><button className="tile" key={m.id} onClick={()=>play(m)}><div
className="poster"><span>{m.ext.toUpperCase()}</span></div><strong>{m.title}</strong><small>{m.position?`Resume at ${fmt(m.position)}`:'Not watched'} · {Math.round(m.size/1024/1024)} MB</small></button>)}</div>}{selected&&<div
className="player"><button className="close" onClick={()=>setSelected(null)}>×</button><div className="playerhead">
<span>Now playing</span><b>{selected.title}</b></div><video ref={video} controls autoPlay src={asset(selected.path)}/><p
className="playernote">Playback uses the browser adapter in this vertical slice. The libmpv spike replaces this adapter before production playback is approved.</p></div>}</main></div>
}
