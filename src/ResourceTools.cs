using System;
using System.IO;
using System.Text;
using System.Collections.Generic;

public class TranslationEntry {
    public string Namespace;
    public string Key;
    public uint Hash;
    public string Text;
}
public static class CabinLocres {
    static string ReadString(BinaryReader r) {
        int n=r.ReadInt32(); if(n==0) return "";
        if(n==Int32.MinValue || Math.Abs(n)>1000000) throw new InvalidDataException("Invalid string length");
        int size=n>0?n:-n*2; byte[] b=r.ReadBytes(size);
        if(b.Length!=size || b[size-1]!=0 || (n<0 && b[size-2]!=0)) throw new InvalidDataException("Invalid string data");
        return (n>0?Encoding.UTF8:Encoding.Unicode).GetString(b,0,size-(n>0?1:2));
    }
    static int Count(BinaryReader r) {
        int n=r.ReadInt32(); if(n<0 || n>1000000) throw new InvalidDataException("Invalid count"); return n;
    }
    static void WriteString(BinaryWriter w,string s) {
        if(s.Length==0) { w.Write(0);return; }
        w.Write(-(s.Length+1)); w.Write(Encoding.Unicode.GetBytes(s)); w.Write((ushort)0);
    }
    static List<TranslationEntry> Read(string path) {
        var result=new List<TranslationEntry>();
        using(var r=new BinaryReader(File.OpenRead(path))) {
            byte[] magic={14,20,116,117,103,74,3,252,74,21,144,157,195,55,127,27};
            byte[] header=r.ReadBytes(16); bool modern=header.Length==16;
            for(int i=0;i<header.Length && modern;i++) if(header[i]!=magic[i])modern=false;
            int version=0; var pool=new List<string>();
            if(modern) { version=r.ReadByte();if(version>3)throw new InvalidDataException("Unsupported locres version"); }
            else r.BaseStream.Position=0;
            if(version>=1) {
                long offset=r.ReadInt64();long pos=r.BaseStream.Position;
                if(offset<0 || offset>=r.BaseStream.Length)throw new InvalidDataException("Invalid string table offset");
                r.BaseStream.Position=offset;int strings=Count(r);
                for(int i=0;i<strings;i++) {pool.Add(ReadString(r));if(version>=2)r.ReadInt32();}
                r.BaseStream.Position=pos;
            }
            if(version>=2)Count(r);
            int namespaces=Count(r);
            for(int i=0;i<namespaces;i++) {
                if(version>=2)r.ReadUInt32();string ns=ReadString(r);int keys=Count(r);
                for(int j=0;j<keys;j++) {
                    if(version>=2)r.ReadUInt32();string key=ReadString(r);uint hash=r.ReadUInt32();string value;
                    if(version>=1) { int idx=r.ReadInt32();if(idx<0 || idx>=pool.Count)throw new InvalidDataException("Invalid string index");value=pool[idx]; }
                    else value=ReadString(r);
                    result.Add(new TranslationEntry{Namespace=ns,Key=key,Hash=hash,Text=value});
                }
            }
        }
        return result;
    }
    public static int Merge(string original,string output,TranslationEntry[] additions) {
        var entries=Read(original);var index=new Dictionary<string,int>();
        for(int i=0;i<entries.Count;i++) index[entries[i].Namespace+"\0"+entries[i].Key]=i;
        foreach(var entry in additions) {
            string id=entry.Namespace+"\0"+entry.Key;int position;
            if(index.TryGetValue(id,out position))entries[position]=entry;
            else {index[id]=entries.Count;entries.Add(entry);}
        }
        var names=new List<string>();var groups=new Dictionary<string,List<TranslationEntry>>();
        foreach(var entry in entries) {
            if(!groups.ContainsKey(entry.Namespace)){names.Add(entry.Namespace);groups.Add(entry.Namespace,new List<TranslationEntry>());}
            groups[entry.Namespace].Add(entry);
        }
        Directory.CreateDirectory(Path.GetDirectoryName(output));
        using(var w=new BinaryWriter(File.Create(output))) {
            w.Write(names.Count);
            foreach(string ns in names) {
                WriteString(w,ns);w.Write(groups[ns].Count);
                foreach(var entry in groups[ns]) {WriteString(w,entry.Key);w.Write(entry.Hash);WriteString(w,entry.Text);}
            }
        }
        var verified=Read(output);
        if(verified.Count!=entries.Count)throw new InvalidDataException("Locres verification failed");
        var verifiedIndex=new Dictionary<string,TranslationEntry>();
        foreach(var entry in verified)verifiedIndex[entry.Namespace+"\0"+entry.Key]=entry;
        for(int i=0;i<entries.Count;i++) {
            var a=entries[i];TranslationEntry b;
            if(!verifiedIndex.TryGetValue(a.Namespace+"\0"+a.Key,out b))throw new InvalidDataException("Missing locres entry");
            if(a.Namespace!=b.Namespace || a.Key!=b.Key || a.Hash!=b.Hash || a.Text!=b.Text)throw new InvalidDataException("Locres content mismatch");
        }
        return entries.Count;
    }
}
