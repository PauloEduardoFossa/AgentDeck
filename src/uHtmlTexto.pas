unit uHtmlTexto;

interface

// Converte o HTML retornado pela API do tiFlux (descricao/comunicacoes) em
// texto/Markdown simples: preserva negrito, italico, listas e links; remove
// o restante das tags. Nao e um parser HTML completo — cobre o que a API
// realmente devolve (paragrafos, quebras de linha, listas, links).
function HtmlParaTexto(const Html: string): string;

implementation

uses
  System.SysUtils, System.RegularExpressions;

function DecodificarEntidades(const Texto: string): string;
begin
  Result := Texto;
  Result := StringReplace(Result, '&nbsp;', ' ', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '&amp;', '&', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '&lt;', '<', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '&gt;', '>', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '&quot;', '"', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '&#39;', '''', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '&apos;', '''', [rfReplaceAll, rfIgnoreCase]);
end;

function HtmlParaTexto(const Html: string): string;
var
  Texto: string;
begin
  if Html = '' then
    Exit('');

  Texto := Html;

  // Links: <a href="URL">texto</a> -> [texto](URL)
  Texto := TRegEx.Replace(Texto, '<a\s+[^>]*href="([^"]*)"[^>]*>(.*?)</a>', '[$2]($1)',
    [TRegExOption.roIgnoreCase, TRegExOption.roSingleLine]);

  // Negrito / italico
  Texto := TRegEx.Replace(Texto, '</?(strong|b)>', '**', [TRegExOption.roIgnoreCase]);
  Texto := TRegEx.Replace(Texto, '</?(em|i)>', '*', [TRegExOption.roIgnoreCase]);

  // Itens de lista
  Texto := TRegEx.Replace(Texto, '<li[^>]*>', '- ', [TRegExOption.roIgnoreCase]);
  Texto := TRegEx.Replace(Texto, '</li>', sLineBreak, [TRegExOption.roIgnoreCase]);
  Texto := TRegEx.Replace(Texto, '</?(ul|ol)[^>]*>', '', [TRegExOption.roIgnoreCase]);

  // Quebras de linha e paragrafos
  Texto := TRegEx.Replace(Texto, '<br\s*/?>', sLineBreak, [TRegExOption.roIgnoreCase]);
  Texto := TRegEx.Replace(Texto, '</p>|</div>', sLineBreak + sLineBreak, [TRegExOption.roIgnoreCase]);
  Texto := TRegEx.Replace(Texto, '<(p|div)[^>]*>', '', [TRegExOption.roIgnoreCase]);

  // Demais tags remanescentes (tabelas, spans, etc.)
  Texto := TRegEx.Replace(Texto, '<[^>]+>', '', []);

  Texto := DecodificarEntidades(Texto);

  // Colapsa 3+ linhas em branco seguidas em no maximo 1 linha em branco
  Texto := TRegEx.Replace(Texto, '(\r?\n){3,}', sLineBreak + sLineBreak, []);

  Result := Trim(Texto);
end;

end.
