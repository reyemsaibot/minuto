let sequence=0;
const pending=new Map<string,{resolve:(value:any)=>void;reject:(reason:Error)=>void}>();
(window as any).nativeResult=(id:string,result:any,error:string|null)=>{const p=pending.get(id);if(!p)return;pending.delete(id);error?p.reject(new Error(error)):p.resolve(result)};
export function native(method:string,payload:unknown={}){return new Promise<any>((resolve,reject)=>{const bridge=(window as any).webkit?.messageHandlers?.kundenzeit;if(!bridge){reject(new Error('Bitte Minuto als Mac-App öffnen.'));return;}const id=String(++sequence);pending.set(id,{resolve,reject});bridge.postMessage({id,method,payload});});}
