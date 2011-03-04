﻿namespace RemObjects.Script.EcmaScript;

interface

uses
  System.Collections.Generic,
  System.Text,
  System.Runtime.CompilerServices,
  RemObjects.Script;
type
  Operators = public partial class
  public
    
    class method PostDecrement(aLeft: Object; aExec: ExecutionContext): Object;
    class method PostIncrement(aLeft: Object; aExec: ExecutionContext): Object;
    class method PreDecrement(aLeft: Object; aExec: ExecutionContext): Object;
    class method PreIncrement(aLeft: Object; aExec: ExecutionContext): Object;

    // OR, AND, ?: have side effects in evaluation and are not specified here.
    class var Method_PostDecrement: System.Reflection.MethodInfo := typeof(Operators).GetMethod('PostDecrement');
    class var Method_PostIncrement: System.Reflection.MethodInfo := typeof(Operators).GetMethod('PostIncrement');
    class var Method_PreDecrement: System.Reflection.MethodInfo := typeof(Operators).GetMethod('PreDecrement');
    class var Method_PreIncrement: System.Reflection.MethodInfo := typeof(Operators).GetMethod('PreIncrement');
  end;

implementation
class method Operators.PostDecrement(aLeft: Object; aExec: ExecutionContext): Object;
begin
  var lRef := Reference(aLeft);
  
  if (lRef <> nil) then begin
    if (lRef.Strict) and (lRef.Base is EnvironmentRecord) and (lRef.Name in ['eval', 'arguments']) then 
      aExec.Global.RaiseNativeError(NativeErrorType.SyntaxError, 'eval/arguments cannot be used in post decrement operator');
    aLeft := Reference.GetValue(lRef, aExec);
  end;
  var lOldValue := aLeft;
  if aLeft is Integer then 
    aLeft := Integer(aLeft) -1
  else
    aLeft := Utilities.GetObjAsDouble(aLeft) -1;
  Reference.SetValue(lRef, aLeft, aExec);
  exit lOldValue;
end;

class method Operators.PostIncrement(aLeft: Object; aExec: ExecutionContext): Object;
begin
end;

class method Operators.PreDecrement(aLeft: Object; aExec: ExecutionContext): Object;
begin
end;

class method Operators.PreIncrement(aLeft: Object; aExec: ExecutionContext): Object;
begin
end;

end.
