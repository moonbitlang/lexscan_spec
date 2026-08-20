// RM-021 LM-035 LS-042
const PREFIX=re"a"

fn canonical(input:String)->Bool{
  input=~((PREFIX+re"b")as whole,before=before,after~)&&whole=="ab"&&before==""&&after==""
}

fn lexical(input:String,scanner:@lexbuf.StringScanner)->Int{
  let a=lexmatch input with first{((re"a"as item),after~,before~,)=>item.to_int();rest=>rest.length()}
  let b=lexscan scanner with longest{((re"^a"as item),)=>item.to_int();_=>0}
  a+b
}

fn placeholders(input:String,scanner:@lexbuf.StringScanner)->Unit{
  lexmatch input{re"^a$"=>();...}
  lexscan scanner{re"^a"=>();...}
}
