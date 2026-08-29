unit uSanitizacao;

interface

// Substitui caracteres nao aceitos pelo Windows em nomes de arquivo/pasta
// (\ / : * ? " < > |) por '-', colapsa espacos/hifens duplicados e remove
// pontos/espacos finais (tambem invalidos no fim do nome).
function NomeArquivoValido(const Nome: string): string;

implementation

uses
  System.SysUtils;

function NomeArquivoValido(const Nome: string): string;
const
  Invalidos: array[0..8] of Char = ('\', '/', ':', '*', '?', '"', '<', '>', '|');
var
  C: Char;
begin
  Result := Nome;
  for C in Invalidos do
    Result := StringReplace(Result, C, '-', [rfReplaceAll]);

  while Pos('--', Result) > 0 do
    Result := StringReplace(Result, '--', '-', [rfReplaceAll]);
  while Pos('  ', Result) > 0 do
    Result := StringReplace(Result, '  ', ' ', [rfReplaceAll]);

  Result := Trim(Result);
  while (Result <> '') and CharInSet(Result[Length(Result)], ['.', ' ']) do
    Delete(Result, Length(Result), 1);
end;

end.
