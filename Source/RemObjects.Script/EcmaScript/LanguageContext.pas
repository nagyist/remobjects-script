﻿{

  Copyright (c) 2009-2010 RemObjects Software. See LICENSE.txt for more details.

}
namespace RemObjects.Script.EcmaScript;

interface

uses
  System.Collections.Generic,
  System.Linq,
  System.Text,
  System.Reflection.Emit,
  RemObjects.Script,
  RemObjects.Script.Properties,
  RemObjects.Script.EcmaScript.Internal;

type
  
  InternalDelegate = public delegate (aScope: ExecutionContext; aSelf: Object; params args: Array of Object): Object;
  EcmaScriptErrorKind = public enum
  (
    FatalErrorWhileCompiling,
    OpeningParenthesisExpected,
    ClosingParenthesisExpected,
    OpeningBraceExpected,
    IdentifierExpected,
    ClosingBraceExpected,
    WhileExpected,
    SemicolonExpected,
    ColonExpected,
    CatchOrFinallyExpected,
    ClosingBracketExpected,
    SyntaxError,
    CommentError,
    EnterInString,
    EOFInRegex,
    EOFInString,
    InvalidEscapeSequence,
    UnknownCharacter,
    OnlyOneVariableAllowed,

    EInternalError = 10001,
    CannotBreakHere,
    DuplicateIdentifier,
    CannotContinueHere,
    CannotReturnHere,
    OnlyOneDefaultAllowed,
    CannotAssignValueToExpression,
    UnknownLabelTarget,
    DuplicateLabel
  );
  ScriptParsingException = public class(ScriptException)
  private
  public
    class method ErrorToString(anError: EcmaScriptErrorKind; aMsg: string): string;
    constructor (aFilename: String; aPosition: PositionPair; anError: EcmaScriptErrorKind; aMsg: String := '');
    property Position: PositionPair; readonly;
    property Error: EcmaScriptErrorKind; readonly;
    property Msg: String; readonly;
  end;

  EcmaScriptException = public ScriptParsingException;
  
  EcmaScriptCompilerOptions = public class
  private
  public
    constructor; empty;
    property EmitDebugCalls: Boolean;
    property Context: EnvironmentRecord;
    property GlobalObject: GlobalObject;
  end;

  EcmaScriptCompiler = public class
  private
    fGlobal: GlobalObject;
    fRoot: EnvironmentRecord;
    fUseStrict: Boolean;
    fDebug: Boolean;
    fExitLabel: Label;
    fResultVar: LocalBuilder;
    fExecutionContext: LocalBuilder;
    fILG: ILGenerator;
    fLocals: List<LocalBuilder>;
    fLoops: List<IterationStatement>;
    method Parse(aFilename, aData: string; aEval: Boolean := false): List<SourceElement>; // eval throws different exception
    method Parse(aOutside, aEval: Boolean; aScopeName: string; aElements: List<SourceElement>): InternalDelegate;
    method PushDebugStack;
    method EmitElement(El: SourceElement);
    method AllocateLocal(aType: &Type): LocalBuilder;
    method ReleaseLocal(aLocal: LocalBuilder);
    method CallGetValue(aFromElement: ElementType);
    method CallSetValue;
    method PushExpression(aExpression: ExpressionElement);
    method RecursiveFindFuncAndVars(aElements: sequence of SourceElement): sequence of SourceElement; iterator;
    method WriteIfStatement(el: IfStatement);
    method WriteDoStatement(el: DoStatement);
    method WriteWhileStatement(el: WhileStatement);
    method WriteForStatement(el: ForStatement);
    method WriteForInstatement(el: ForInStatement);
    method WriteContinue(el: ContinueStatement);
    method WriteBreak(el: BreakStatement);
    method WriteLabelled(aLabel: LabelledStatement);
  public
    constructor(aOptions: EcmaScriptCompilerOptions);


    property GlobalObject: GlobalObject read fGlobal;
    
    method EvalParse(aData: string): InternalDelegate;
    method Parse(aFilename, aData: string): InternalDelegate;
  end;

  DynamicMethods = public static class
  private
  public

  end;

  CodeDelegate = public delegate (aScope: ExecutionContext; Args: array of Object): Object;

implementation


constructor ScriptParsingException(aFilename: String; aPosition: PositionPair; anError: EcmaScriptErrorKind; aMsg: String := '');
begin
  inherited constructor(String.Format('{0}({1}:{2}) {3} {4}', aFilename, 
    aPosition.StartRow, aPosition.StartCol, Integer(anError), ErrorToString(anError, aMsg)));
  Position := aPosition;
  Error := anError;
  Msg := aMsg;

end;

class method ScriptParsingException.ErrorToString(anError: EcmaScriptErrorKind; aMsg: string): string;
begin
  case anError of
    ParserErrorKind.OpeningParenthesisExpected:  result := Resources.eOpeningParenthesisExpected;
    ParserErrorKind.OpeningBraceExpected: result := Resources.eOpeningBraceExpected;
    ParserErrorKind.ClosingParenthesisExpected: result := Resources.eClosingParenthesisExpected;
    ParserErrorKind.IdentifierExpected: result := Resources.eIdentifierExpected;
    ParserErrorKind.ClosingBraceExpected: result := Resources.eClosingBraceExpected;
    ParserErrorKind.WhileExpected: result := Resources.eWhileExpected;
    ParserErrorKind.SemicolonExpected: result := Resources.eSemicolonExpected;
    ParserErrorKind.ColonExpected: result := Resources.eColonExpected;
    ParserErrorKind.CatchOrFinallyExpected: result := Resources.eCatchOrFinallyExpected;
    ParserErrorKind.ClosingBracketExpected: result := Resources.eClosingBracketExpected;
    ParserErrorKind.SyntaxError: Result := Resources.eSyntaxError;
    ParserErrorKind.CommentError: Result := Resources.eCommentError;
    ParserErrorKind.EnterInString: Result := Resources.eEnterInString;
    ParserErrorKind.EOFInRegex: Result := Resources.eEOFInRegex;
    ParserErrorKind.EOFInString: Result := Resources.eEOFInString;
    ParserErrorKind.InvalidEscapeSequence: Result := Resources.eInvalidEscapeSequence;
    ParserErrorKind.UnknownCharacter: Result := Resources.eUnknownCharacter;
    ParserErrorKind.OnlyOneVariableAllowed: result := Resources.eOnlyOneVariableAllowed;
    EcmaScriptErrorKind.CannotBreakHere: result := String.Format(Resources.eCannotBreakHere, aMsg);
    EcmaScriptErrorKind.CannotContinueHere: result := String.Format(Resources.eCannotBreakHere, aMsg);
    EcmaScriptErrorKind.DuplicateIdentifier: result := String.Format(Resources.eDuplicateIdentifier, aMsg);
    EcmaScriptErrorKind.EInternalError: result := String.Format(Resources.eInternalError, aMsg);
    EcmaScriptErrorKind.CannotReturnHere: result := String.Format(Resources.eCannotReturnHere, aMsg);
    EcmaScriptErrorKind.OnlyOneDefaultAllowed: result := string.Format(Resources.eOnlyOneDefaultAllowed, aMsg);
    EcmaScriptErrorKind.CannotAssignValueToExpression: result := String.Format(Resources.eCannotAssignValueToExpression, aMsg);
    EcmaScriptErrorKind.UnknownLabelTarget:result := String.Format(Resources.eUnknownLabelTarget, aMsg);
    EcmaScriptErrorKind.DuplicateLabel: result := String.Format(Resources.eDuplicateIdentifier, aMsg);
  else
    result := Resources.eSyntaxError;
  end; // case
end;


method EcmaScriptCompiler.Parse(aFilename, aData: string; aEval: Boolean := false): List<SourceElement>;
begin
  var lTokenizer := new Tokenizer;
  var lParser := new Parser;
  lTokenizer.Error += lParser.fTok_Error;
  lTokenizer.SetData(aData, aFilename);
  lTokenizer.Error -= lParser.fTok_Error;
  var lElement := lParser.Parse(lTokenizer);
  for each el in lParser.Messages do begin
    if el.IsError then
    raise new ScriptParsingException(aFilename, new PositionPair(el.Position, el.Position), EcmaScriptErrorKind(el.Code));
  end;
  exit lElement.Items;
end;

constructor EcmaScriptCompiler(aOptions: EcmaScriptCompilerOptions);
begin
  fGlobal := aOptions:GlobalObject;
  if assigned(aOptions) then
    fDebug := aOptions.EmitDebugCalls;
  if fGlobal = nil then fGlobal := new GlobalObject(self);
  fRoot := new ObjectEnvironmentRecord(aOptions:Context, fGlobal, false);
end;


method EcmaScriptCompiler.EvalParse(aData: string): InternalDelegate;
begin
  exit Parse(false, true, '<eval>', Parse('<eval>', aData, true));
end;

method EcmaScriptCompiler.Parse(aFilename, aData: string): InternalDelegate;
begin
  exit Parse(true, false, aFilename, Parse( aFilename, aData, false));
end;

method EcmaScriptCompiler.Parse(aOutside, aEval: Boolean; aScopeName: string; aElements: List<SourceElement>): InternalDelegate;
begin
  var lUseStrict := fUseStrict;
  var lLoops := fLoops;
  fLoops := new List<IterationStatement>;
  try
    if aElements.Count <> 0 then begin
      if aElements[aElements.Count-1].Type <> ElementType.ExpressionStatement then
        aElements.Add(new ReturnStatement(new PositionPair(), new IdentifierExpression(new PositionPair, 'undefined')))
      else begin
        var lEl := ExpressionStatement(aElements[aElements.Count-1]).ExpressionElement;
        aElements[aElements.Count-1] := new ReturnStatement(lEl.PositionPair, lEl);
      end;
      if aElements.Count > 1 then begin
        if (aElements[0].Type = ElementType.ExpressionStatement) and (ExpressionStatement(aElements[0]).ExpressionElement.Type = ElementType.StringExpression) then begin
          if StringExpression(ExpressionStatement(aElements[0]).ExpressionElement).Value = 'use strict' then begin
            fUseStrict := true;
            aElements.RemoveAt(0);
          end;
        end;
      end;
    end else
      aElements.Add(new ReturnStatement(new PositionPair(), new IdentifierExpression(new PositionPair, 'undefined')));

    var lOldLocals := fLocals;
    fLocals := new List<LocalBuilder>;
    var lMethod := new System.Reflection.Emit.DynamicMethod(aSCopeName, typeof(Object), [typeof(ExecutionContext), typeof(object), Typeof(array of Object)], typeof(DynamicMethods), true);

    fILG := lMethod.GetILGenerator();
    fExecutionContext := fILG.DeclareLocal(typeof(ExecutionContext));
    fILG.Emit(OpCodes.Ldarg_0);  // first execution context
    fILG.Emit(Opcodes.Stloc, fExecutionContext);
    if fDebug then begin
      PushDebugStack;
      filg.Emit(OpCodes.Ldstr, aScopeName);
      filg.Emit(Opcodes.Ldloc, fExecutionContext);
      filg.Emit(Opcodes.Callvirt, DebugSink.Method_EnterScope);
      fILG.BeginExceptionBlock; // finally
      if aOutside then
        fILG.BeginExceptionBlock; // except
    end;
    var lOldExitLabel := fExitLabel;
    var lOldResultVar := fResultVar;
    fExitLabel := filg.DefineLabel;
    fResultVar := filg.DeclareLocal(typeof(Object));
    filg.Emit(Opcodes.Call, Undefined.Method_Instance);
    filg.Emit(Opcodes.Stloc, fResultVar);

    if not aEval and not aOutside then begin
      filg.Emit(Opcodes.Ldarg_1); // this
      var lIsNull := filg.DefineLabel;
      filg.Emit(Opcodes.Brfalse, lIsNull);
      filg.Emit(Opcodes.Ldarg_1); // this
      filg.Emit(OpCodes.Call, Undefined.Method_Instance);
      filg.Emit(opcodes.Beq, lIsnull);
      var lGotThis := filg.DefineLabel;
      filg.Emit(Opcodes.Br, lGotThis);
      filg.MarkLabel(lIsNull);
      filg.Emit(OpCodes.Ldloc, fExecutionContext);
      filg.Emit(Opcodes.Call, ExecutionContext.Method_get_Global);
      filg.Emit(Opcodes.Starg, 1); // this
      filg.MarkLabel(lGotThis);
    end;

    for each el in RecursiveFindFuncAndVars(aElements) do begin
      if el.Type = ElementType.FunctionDeclaration then begin
        filg.Emit(Opcodes.Ldloc, fExecutionContext);
        filg.Emit(Opcodes.Call, ExecutionContext.Method_get_VariableScope);
        filg.Emit(Opcodes.Ldstr, FunctionDeclarationElement(el).Identifier);
        if aEval then
          filg.Emit(Opcodes.Ldc_I4_1) 
        else
          filg.Emit(Opcodes.Ldc_I4_0);
        filg.Emit(Opcodes.Call, EnvironmentRecord.Method_CreateMutableBindingNoFail);
        filg.Emit(Opcodes.Ldloc, fExecutionContext);
        filg.Emit(Opcodes.Call, ExecutionContext.Method_get_VariableScope);
        filg.Emit(Opcodes.Ldstr, FunctionDeclarationElement(el).Identifier);
        PushExpression(new FunctionExpression(el.PositionPair, FunctionDeclarationElement(el)));
        if fUseStrict then
          filg.Emit(Opcodes.Ldc_I4_1) 
        else
          filg.Emit(Opcodes.Ldc_I4_0);
        filg.Emit(Opcodes.Callvirt, EnvironmentRecord.Method_SetMutableBinding);
      end else if el.Type = ElementType.VariableStatement then begin
        for each en in VariableStatement(el).Items do begin
          filg.Emit(Opcodes.Ldloc, fExecutionContext);
          filg.Emit(Opcodes.Call, ExecutionContext.Method_get_VariableScope);
          filg.Emit(Opcodes.Ldstr, en.Identifier);
          if aEval then
            filg.Emit(Opcodes.Ldc_I4_1) 
          else
            filg.Emit(Opcodes.Ldc_I4_0);
          filg.Emit(Opcodes.Call, EnvironmentRecord.Method_CreateMutableBindingNoFail);
        end;
      end;
    end;

    for i: Integer := 0 to aElements.Count -1 do
      EmitElement(aElements[i]);

    if fDebug then begin
      filg.BeginFinallyBlock();
      PushDebugStack;
      filg.Emit(OpCodes.Ldstr, aScopeName);
      filg.Emit(Opcodes.Ldloc, fExecutionContext);
      filg.Emit(Opcodes.Callvirt, DebugSink.Method_ExitScope);
      filg.EndExceptionBlock();
      if aOutside then begin
        filg.BeginCatchBlock(typeof(Exception));
        var lTemp := AllocateLocal(typeof(Exception));
        filg.Emit(Opcodes.Stloc, lTemp);
        PushDebugStack;
        filg.Emit(Opcodes.Ldloc, lTemp);
        filg.Emit(Opcodes.Callvirt, Debugsink.Method_UncaughtException);
        filg.Emit(Opcodes.Rethrow);
        ReleaseLocal(lTemp);
        filg.EndExceptionBlock();
      end;
    end;
    filg.MarkLabel(fExitLabel);
    filg.Emit(Opcodes.Ldloc, fResultVar);
    filg.Emit(Opcodes.Ret);
  
    fExitLabel := lOldExitLabel;
    fResultVar := lOldResultVar;
    fLocals := lOldLocals;
    exit InternalDelegate(lMethod.CreateDelegate(typeof(InternalDelegate)));
  finally
    fUseStrict := lUseStrict;
    fLoops := lLoops;
  end;
end;

method EcmaScriptCompiler.PushDebugStack;
begin
  fILG.Emit(Opcodes.Ldloc, fExecutionContext);
  filg.Emit(Opcodes.Call, ExecutionContext.Method_GetDebugSink);
end;

method EcmaScriptCompiler.EmitElement(El: SourceElement);
begin
  if fDebug and (el.PositionPair.StartRow> 0) then begin
    PushDebugStack;
    var lPos := el.PositionPair;
    filg.Emit(opcodes.Ldstr, lPos.File);
    filg.Emit(Opcodes.Ldc_I4, lPos.StartRow);
    filg.Emit(Opcodes.Ldc_I4, lPos.StartCol);
    filg.Emit(Opcodes.Ldc_I4, lPos.EndRow);
    filg.Emit(Opcodes.Ldc_I4, lPos.EndCol);
    filg.Emit(Opcodes.Callvirt, DebugSink.Method_DebugLine);
  end;

  case el.Type of
    ElementType.EmptyStatement: begin
      filg.Emit(Opcodes.Nop);
    end;

    ElementType.ReturnStatement: begin
      PushExpression(ReturnStatement(el).ExpressionElement);
      CallGetValue(ReturnStatement(el).ExpressionElement.Type);
      filg.Emit(Opcodes.Stloc, fResultVar);
      filg.Emit(Opcodes.Leave, fExitLabel);
    end;
    ElementType.ExpressionStatement: begin
      PushExpression(ExpressionStatement(el).ExpressionElement);
      filg.Emit(Opcodes.Pop);
    end;
    ElementType.DebuggerStatement: begin
      PushDebugStack;
      filg.Emit(opcodes.Callvirt, DebugSink.Method_Debugger);
    end;
    ElementType.VariableStatement: begin
      for i: Integer := 0 to VariableStatement(El).Items.Count- 1 do begin
        var lItem := VariableStatement(el).Items[i];
        if lItem.Initializer <> nil then begin
          PushExpression(new BinaryExpression(lItem.PositionPair, new IdentifierExpression(lItem.PositionPair, lItem.Identifier), lItem.Initializer, BinaryOperator.Assign));
        end;
      end;
    end;
    ElementType.BlockStatement: begin
      for each subitem in BlockStatement(el).Items do EmitElement(subitem);
    end;
    ElementType.IfStatement: WriteIfStatement(IfStatement(El));
    ElementType.BreakStatement: WriteBreak(BreakStatement(El));
    ElementType.ContinueStatement: WriteContinue(ContinueStatement(el));
    ElementType.DoStatement: WriteDoStatement(DoStatement(el));
    ElementType.ForInStatement: WriteForInstatement(ForInStatement(el));
    ElementType.ForStatement: WriteForStatement(ForStatement(el));
    ElementType.WhileStatement: WriteWhileStatement(WhileStatement(el));
    
    (*
    ElementType.CaseClause: ;
    ElementType.CatchBlock: ;
    ElementType.FunctionDeclaration: ;
    ElementType.LabelledStatement: ;
    ElementType.ParameterDeclaration: ;
    ElementType.Program: ;
    ElementType.PropertyAssignment: ;
    ElementType.SwitchStatement: ;
    ElementType.ThrowStatement: ;
    ElementType.TryStatement: ;
    ElementType.WithStatement: ;;*)
  else
    raise new EcmascriptException(El.PositionPair.File, el.PositionPair, EcmaScriptErrorKind.EInternalError, 'Unkwown type: '+el.Type);
  end; // case
end;

method EcmaScriptCompiler.AllocateLocal(aType: &Type): LocalBuilder;
begin
  for i: Integer := 0 to fLocals.Count -1 do begin
    if fLocals[i].LocalType = aType then begin
      var lItem := fLocals[i];
      fLocals.RemoveAt(i);
      exit lItem;
    end;
  end;
  result := filg.DeclareLocal(aType);
end;

method EcmaScriptCompiler.ReleaseLocal(aLocal: LocalBuilder);
begin
  fLocals.Add(aLocal);
end;

method EcmaScriptCompiler.PushExpression(aExpression: ExpressionElement);
begin
  case aExpression.Type of
    ElementType.ThisExpression: begin
      filg.Emit(Opcodes.Ldarg_1); // this is arg nr 1
    end;
    ElementType.NullExpression: filg.Emit(Opcodes.Ldnull);
    ElementType.BooleanExpression: begin
      if BooleanExpression(aExpression).Value then
        filg.Emit(Opcodes.Ldc_I4_1)
      else
        filg.Emit(Opcodes.Ldc_I4_0);
      filg.Emit(Opcodes.Box, typeof(Boolean));
    end;
    ElementType.IntegerExpression: begin
      if (IntegerExpression(aExpression).Value < Int64(Int32.MinValue)) or (IntegerExpression(aExpression).Value > Int64(Int32.MaxValue)) then begin
        filg.Emit(Opcodes.Ldc_R8, Double(IntegerExpression(aExpression).Value));
        filg.Emit(Opcodes.Box, typeof(Double));
      end else begin
        filg.Emit(Opcodes.Ldc_I4, IntegerExpression(aExpression).Value);
        filg.Emit(Opcodes.Box, typeof(Integer));
      end;
    end;
    ElementType.DecimalExpression: begin
      filg.Emit(Opcodes.Ldc_R8, DecimalExpression(aExpression).Value);
      filg.Emit(Opcodes.Box, typeof(Double));
    end;
    ElementType.RegExExpression: begin
      fILG.Emit(Opcodes.Ldloc, fExecutionContext);
      filg.Emit(Opcodes.Call, ExecutionContext.Method_get_Global);
      filg.Emit(Opcodes.Ldstr, RegExExpression(aExpression).String);
      filg.Emit(Opcodes.Ldstr, RegExExpression(aExpression).Modifier);
      filg.Emit(Opcodes.Newobj,typeof(EcmaScriptRegexpObject).GetConstructor([typeof(GlobalObject), typeof(String), typeof(String)]));
    end;
    ElementType.UnaryExpression: begin
      case UnaryExpression(aExpression).Operator of
        UnaryOperator.BinaryNot: begin
          PushExpression(UnaryExpression(aExpressioN).Value);
          CallGetValue(UnaryExpression(aExpressioN).Value.Type);
          filg.Emit(Opcodes.Call, Operators.Method_BitwiseNot);
        end;
        UnaryOperator.BoolNot: begin
          PushExpression(UnaryExpression(aExpressioN).Value);
          CallGetValue(UnaryExpression(aExpressioN).Value.Type);
          filg.Emit(Opcodes.Call, Operators.Method_LogicalNot);
        end;

        UnaryOperator.Delete: begin
          PushExpression(UnaryExpression(aExpressioN).Value);
          filg.Emit(Opcodes.Ldloc, fExecutionContext);
          filg.Emit(Opcodes.Call, Reference.Method_Delete);
          filg.Emit(Opcodes.Box, typeof(Boolean));
        end;

        UnaryOperator.Minus: begin
          PushExpression(UnaryExpression(aExpressioN).Value);
          CallGetValue(UnaryExpression(aExpressioN).Value.Type);
          filg.Emit(Opcodes.Call, Operators.Method_Minus);
        end;

        UnaryOperator.Plus: begin
          PushExpression(UnaryExpression(aExpressioN).Value);
          CallGetValue(UnaryExpression(aExpressioN).Value.Type);
          filg.Emit(Opcodes.Call, Operators.Method_Plus);
        end;
        UnaryOperator.PostDecrement: begin
          PushExpression(UnaryExpression(aExpressioN).Value);
          filg.Emit(Opcodes.Ldloc, Operators.Method_PostDecrement);
        end;

        UnaryOperator.PostIncrement: begin
          PushExpression(UnaryExpression(aExpressioN).Value);
          filg.Emit(Opcodes.Ldloc, Operators.Method_PostIncrement);
        end;
        UnaryOperator.PreDecrement: begin
          PushExpression(UnaryExpression(aExpressioN).Value);
          filg.Emit(Opcodes.Ldloc, Operators.Method_PreDecrement);
        end;
        UnaryOperator.PreIncrement: begin
          PushExpression(UnaryExpression(aExpressioN).Value);
          filg.Emit(Opcodes.Ldloc, Operators.Method_PreIncrement);
        end;
        UnaryOperator.TypeOf: begin
          PushExpression(UnaryExpression(aExpressioN).Value);
          CallGetValue(UnaryExpression(aExpressioN).Value.Type);
          filg.Emit(Opcodes.Call, Operators.Method_TypeOf);
        end;
        UnaryOperator.Void: begin
          PushExpression(UnaryExpression(aExpressioN).Value);
          CallGetValue(UnaryExpression(aExpressioN).Value.Type);
          filg.Emit(Opcodes.Pop);
          filg.Emit(OpCodes.Call, Undefined.Method_Instance);
        end;
        else raise new EcmaScriptException(aExpression.PositionPair.File, aExpression.PositionPair, EcmaScriptErrorKind.EInternalError, 'Unknown type: '+aExpression.Type);
      end; // case
    end;
    ElementType.IdentifierExpression: begin
      filg.Emit(OpCodes.Ldloc, fExecutionContext);
      filg.Emit(Opcodes.Ldstr, IdentifierExpression(aExpression).Identifier);
      if fUseStrict then
        filg.Emit(Opcodes.Ldc_I4_1)
      else
        filg.Emit(Opcodes.Ldc_I4_0);
      filg.Emit(Opcodes.Call, EnvironmentRecord.Method_GetIdentifier);
    end;
    ElementType.BinaryExpression: begin
      case BinaryExpression(aExpression).Operator of
        BinaryOperator.Assign: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Ldloc, fExecutionContext);
          filg.Emit(Opcodes.Call,  Reference.Method_SetValue);
        end;
        BinaryOperator.Plus: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_Add);
        end;
        BinaryOperator.PlusAssign: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          filg.Emit(Opcodes.Dup);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_Add);
          filg.Emit(OpCodes.Ldloc, fExecutionContext);
          fILG.Emit(Opcodes.Call, Reference.Method_SetValue);
        end;
        BinaryOperator.Divide: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_Divide);
        end;
        BinaryOperator.DivideAssign: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          filg.Emit(Opcodes.Dup);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_Divide);
          filg.Emit(OpCodes.Ldloc, fExecutionContext);
          fILG.Emit(Opcodes.Call, Reference.Method_SetValue);
        end;
        BinaryOperator.Minus: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_Minus);
        end;
        BinaryOperator.MinusAssign: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          filg.Emit(Opcodes.Dup);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_Minus);
          filg.Emit(OpCodes.Ldloc, fExecutionContext);
          fILG.Emit(Opcodes.Call, Reference.Method_SetValue);
        end;

        BinaryOperator.Modulus: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_Modulus);
        end;
        BinaryOperator.ModulusAssign: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          filg.Emit(Opcodes.Dup);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_Modulus);
          filg.Emit(OpCodes.Ldloc, fExecutionContext);
          fILG.Emit(Opcodes.Call, Reference.Method_SetValue);
        end;

        BinaryOperator.Multiply: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_Multiply);
        end;
        BinaryOperator.MultiplyAssign: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          filg.Emit(Opcodes.Dup);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_Multiply);
          filg.Emit(OpCodes.Ldloc, fExecutionContext);
          fILG.Emit(Opcodes.Call, Reference.Method_SetValue);
        end;

        BinaryOperator.ShiftLeft: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_ShiftLeft);
        end;
        BinaryOperator.ShiftLeftAssign: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          filg.Emit(Opcodes.Dup);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_ShiftLeft);
          filg.Emit(OpCodes.Ldloc, fExecutionContext);
          fILG.Emit(Opcodes.Call, Reference.Method_SetValue);
        end;

        BinaryOperator.ShiftRightSigned: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_ShiftRight);
        end;
        BinaryOperator.ShiftRightSignedAssign: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          filg.Emit(Opcodes.Dup);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_ShiftRight);
          filg.Emit(OpCodes.Ldloc, fExecutionContext);
          fILG.Emit(Opcodes.Call, Reference.Method_SetValue);
        end;

        BinaryOperator.ShiftRightUnsigned: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_ShiftRightUnsigned);
        end;
        BinaryOperator.ShiftRightUnsignedAssign: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          filg.Emit(Opcodes.Dup);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_ShiftRightUnsigned);
          filg.Emit(OpCodes.Ldloc, fExecutionContext);
          fILG.Emit(Opcodes.Call, Reference.Method_SetValue);
        end;
        BinaryOperator.And: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_And);
        end;
        BinaryOperator.AndAssign: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          filg.Emit(Opcodes.Dup);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_And);
          filg.Emit(OpCodes.Ldloc, fExecutionContext);
          fILG.Emit(Opcodes.Call, Reference.Method_SetValue);
        end;
        BinaryOperator.Or: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_Or);
        end;
        BinaryOperator.OrAssign: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          filg.Emit(Opcodes.Dup);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_OR);
          filg.Emit(OpCodes.Ldloc, fExecutionContext);
          fILG.Emit(Opcodes.Call, Reference.Method_SetValue);
        end;
        BinaryOperator.Xor, BinaryOperator.DoubleXor: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_XOr);
        end;
        BinaryOperator.XorAssign: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          filg.Emit(Opcodes.Dup);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_XOr);
          filg.Emit(OpCodes.Ldloc, fExecutionContext);
          fILG.Emit(Opcodes.Call, Reference.Method_SetValue);
        end;

        BinaryOperator.Equal: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_Equal);
        end;

        BinaryOperator.NotEqual: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_NotEqual);
        end;

        BinaryOperator.StrictEqual: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_StrictEqual);
        end;

        BinaryOperator.StrictNotEqual: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_StrictNotEqual);
        end;

        BinaryOperator.Less: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_LessThan);
        end;
        BinaryOperator.Greater: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_GreaterThan);
        end;
        BinaryOperator.LessOrEqual: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_LessThanOrEqual);
        end;
        BinaryOperator.GreaterOrEqual: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_GreaterThanOrEqual);
        end;        
        BinaryOperator.InstanceOf: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_InstanceOf);
        end;
        BinaryOperator.In: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.Emit(Opcodes.Call, Operators.Method_In);
        end;
        BinaryOperator.DoubleAnd: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          filg.Emit(Opcodes.Dup);
          filg.Emit(Opcodes.Call, Utilities.method_GetObjAsBoolean);
          var lGotIt := filg.DefineLabel;
          filg.Emit(OpCodes.Brfalse, lGotIt);
          filg.Emit(Opcodes.Pop);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.MarkLabel(lGotIt);
        end;
        BinaryOperator.DoubleOr: begin
          PushExpression(BinaryExpression(aExpression).LeftSide);
          CallGetValue(BinaryExpression(aExpression).LeftSide.Type);
          filg.Emit(Opcodes.Dup);
          filg.Emit(Opcodes.Call, Utilities.method_GetObjAsBoolean);
          var lGotIt := filg.DefineLabel;
          filg.Emit(OpCodes.Brtrue, lGotIt);
          filg.Emit(Opcodes.Pop);
          PushExpression(BinaryExpression(aExpression).RightSide);
          CallGetValue(BinaryExpression(aExpression).RightSide.Type);
          filg.MarkLabel(lGotIt);
        end;
      else
        raise new EcmaScriptException(aExpression.PositionPair.File, aExpression.PositionPair, EcmaScriptErrorKind.EInternalError, 'Unknown type: '+aExpression.Type);
      end; // case
    end;
    ElementType.ConditionalExpression: begin
      PushExpression(ConditionalExpression(aExpression).Condition);
      CallGetValue(ConditionalExpression(aExpression).Condition.Type);
      filg.Emit(Opcodes.Call, Utilities.method_GetObjAsBoolean);
      var lFalse := filg.DefineLabel;
      var lExit := filg.DefineLabel;
      filg.Emit(Opcodes.Brfalse, lFalse);
      PushExpression(ConditionalExpression(aExpression).True);
      CallGetValue(ConditionalExpression(aExpression).True.Type);
      filg.Emit(Opcodes.Br, lExit);
      filg.MarkLabel(lFAlse);
      PushExpression(ConditionalExpression(aExpression).False);
      CallGetValue(ConditionalExpression(aExpression).false.Type);
      filg.MarkLabel(lExit);
    end;
    ElementType.ArrayLiteralExpression: begin
      filg.Emit(Opcodes.Ldc_I4, ArrayLiteralExpression(aExpression).Items.Count);
      filg.Emit(Opcodes.Ldloc, fExecutionContext);
      filg.Emit(Opcodes.Call, ExecutionContext.Method_get_Global);
      filg.Emit(Opcodes.Newobj, EcmaScriptArrayObject.Constructor);
      for each el in ArrayLiteralExpression(aExpression).Items do begin
        filg.Emit(Opcodes.Dup);
        PushExpression(el);
        CallGetValue(el.Type);
        filg.Emit(Opcodes.Call, EcmaScriptArrayObject.Method_AddValue);
      end;
    end;
    ElementType.ObjectLiteralExpression: begin
      filg.Emit(Opcodes.Ldloc, fExecutionContext);
      filg.Emit(Opcodes.Call, ExecutionContext.Method_get_Global);
      filg.Emit(Opcodes.Newobj, EcmaScriptObject.Constructor);
      for each el in ObjectLiteralExpression(aExpression).Items do begin
        case el.Name.Type of 
          ElementType.IdentifierExpression: filg.Emit(Opcodes.Ldstr, IdentifierExpression(el.Name).Identifier);
        else
          PushExpression(el.Name);
        end; // case
        filg.Emit(Opcodes.Call, Utilities.Method_GetObjAsString);
        filg.Emit(OpCodes.Ldc_I4, Integer(el.Mode));
        PushExpression(el.Value);
        CallGetValue(El.Value.Type);
        filg.Emit(Opcodes.Ldc_I4, if fUseStrict then 1 else 0);
        filg.Emit(Opcodes.Call, EcmaScriptObject.Method_ObjectLiteralSet);
      end;
    end;
    ElementType.SubExpression: begin
      PushExpression(SubExpression(aExpression).Member);
      CallGetValue(SubExpression(aExpression).Member.Type);
      filg.emit(Opcodes.Ldstr, SubExpression(aExpression).Identifier);
      filg.Emit(Opcodes.Ldloc, fExecutionContext);
      filg.Emit(Opcodes.Ldc_I4, if fUseStrict then 1 else 0);
      filg.Emit(Opcodes.Call, Reference.Method_Create);
    end;
    ElementType.ArrayAccessExpression: begin
      PushExpression(ArrayAccessExpression(aExpression).Member);
      CallGetValue(ArrayAccessExpression(aExpression).Member.Type);
      PushExpression(ArrayAccessExpression(aExpression).Parameter);
      CallGetValue(ArrayAccessExpression(aExpression).Parameter.Type);
      filg.Emit(Opcodes.Ldc_I4, if fUseStrict then 1 else 0);
      filg.Emit(Opcodes.Call, Reference.Method_Create);
    end;
    ElementType.NewExpression: begin
      PushExpression(NewExpression(aExpression).Member);
      CallGetValue(NewExpression(aExpression).Member.Type);
      filg.Emit(Opcodes.Isinst, typeof(EcmaScriptObject));
      filg.Emit(Opcodes.Dup);
      var lIsObject := filg.DefineLabel;
      filg.Emit(Opcodes.Brtrue, lIsObject);
      filg.Emit(OpCodes.Ldloc, fExecutionContext);
      filg.Emit(Opcodes.Call, ExecutionContext.Method_get_Global);
      filg.Emit(Opcodes.Ldc_I4, Integer(NativeErrorType.TypeError));
      filg.Emit(Opcodes.Ldstr, 'Cannot instantiate non-object value');
      filg.Emit(Opcodes.Call, GlobalObject.Method_RaiseNativeError);
      filg.MarkLabel(lIsObject);
      filg.Emit(Opcodes.Ldloc, fExecutionContext);
      filg.Emit(Opcodes.Ldc_I4, NewExpression(aExpression).Parameters.Count);
      filg.Emit(Opcodes.Newarr, typeof(Object));
      for each el in NewExpression(aExpression).Parameters index n do begin
        filg.Emit(OpCodes.Dup);
        filg.Emit(Opcodes.Ldc_I4, n);
        PushExpression(el);
        CallGetValue(el.Type);
        filg.Emit(Opcodes.Stelem_Ref);
      end;

      filg.Emit(Opcodes.Callvirt, EcmaScriptObject.Method_Construct);
    end;

    ElementType.CallExpression: begin
      PushExpression(CallExpression(aExpression).Member);
      filg.Emit(Opcodes.Dup);   

      CallGetValue(CallExpression(aExpression).Member.Type);
      filg.Emit(Opcodes.Isinst, typeof(EcmaScriptObject));
      filg.Emit(Opcodes.Dup);
      var lIsObject := filg.DefineLabel;
      filg.Emit(Opcodes.Brtrue, lIsObject);
      filg.Emit(OpCodes.Ldloc, fExecutionContext);
      filg.Emit(Opcodes.Call, ExecutionContext.Method_get_Global);
      filg.Emit(Opcodes.Ldc_I4, Integer(NativeErrorType.TypeError));
      filg.Emit(Opcodes.Ldstr, 'Cannot call non-object value');
      filg.Emit(Opcodes.Call, GlobalObject.Method_RaiseNativeError);
      filg.MarkLabel(lIsObject);
      
      filg.Emit(Opcodes.Ldc_I4, CallExpression(aExpression).Parameters.Count);
      filg.Emit(Opcodes.Newarr, typeof(Object));
      for each el in CallExpression(aExpression).Parameters index n do begin
        filg.Emit(OpCodes.Dup);
        filg.Emit(Opcodes.Ldc_I4, n);
        PushExpression(el);
        CallGetValue(el.Type);
        filg.Emit(Opcodes.Stelem_Ref);
      end;
      filg.Emit(Opcodes.Ldloc, fExecutionContext);
      filg.Emit(Opcodes.Call, EcmaScriptObject.Method_CallHelper);
    end
    (*: ;
    
    ElementType.CommaSeparatedExpression: ;
    : ;
    ElementType.FunctionExpression: ;
    
    : ;*)
  else
    raise new EcmaScriptException(aExpression.PositionPair.File, aExpression.PositionPair, EcmaScriptErrorKind.EInternalError, 'Unknown type: '+aExpression.Type);
  end; // case
end;

method EcmaScriptCompiler.CallGetValue(aFromElement: ElementType);
begin
  case aFromElement of
    ElementType.SubExpression,
    ElementType.CallExpression,
    ElementType.IdentifierExpression: ;
  else
    exit; // not needed
  end; // case
  // Expect: POSSIBLE reference on stack (always typed object)
  // Returns: Object value
  filg.Emit(Opcodes.Ldloc, fExecutionContext);
  filg.Emit(Opcodes.Call, Reference.Method_GetValue);

end;

method EcmaScriptCompiler.CallSetValue;
begin
  // Expect: POSSIBLE reference on stack (always typed object)
  // Expect: NON reference as second item on the stack
  // Returns: Object value
  filg.Emit(Opcodes.Ldloc, fExecutionContext);
  filg.Emit(Opcodes.Call, Reference.Method_SetValue);
end;

method EcmaScriptCompiler.RecursiveFindFuncAndVars(aElements: sequence of SourceElement): sequence of SourceElement;
begin
  for each el in aElements do begin
    if el = nil then continue;
    case el.Type of
      ElementType.BlockStatement: yield RecursiveFindFuncAndVars(BlockStatement(el).Items.Cast<SourceElement>);
      ElementType.IfStatement: yield RecursiveFindFuncAndVars([IfStatement(el).True, IfStatement(el).False]);
      ElementType.LabelledStatement: yield RecursiveFindFuncAndVars([LabelledStatement(el).Statement]);
      ElementType.SwitchStatement: RecursiveFindFuncAndVars(SwitchStatement(el).Clauses.SelectMany(a->a.Body.Cast<SourceElement>()));
      ElementType.TryStatement: RecursiveFindFuncAndVars([TryStatement(el).Body, TryStatement(el).Finally, TryStatement(el).Catch:Body]);
      ElementType.VariableStatement: yield el;
      ElementType.WithStatement: yield RecursiveFindFuncAndVars([WithStatement(el).Body]);
      ElementType.DoStatement: yield RecursiveFindFuncAndVars([DoStatement(el).Body]);
      ElementType.ForInStatement: yield RecursiveFindFuncAndVars([ForInStatement(el).ExpressionElement, ForInStatement(el).Body]);
      ElementType.ForStatement: yield RecursiveFindFuncAndVars([ForStatement(el).Initializer, ForStatement(el).Increment, ForStatement(el).Comparison, ForStatement(el).Body]);
      ElementType.WhileStatement: yield RecursiveFindFuncAndVars([WhileStatement(el).Body]);
    end; // case
  end;
end;

method EcmaScriptCompiler.WriteIfStatement(el: IfStatement);
begin
  if el.False = nil then begin
    PushExpression(el.ExpressionElement);
    filg.Emit(Opcodes.Call, Utilities.method_GetObjAsBoolean);
    var lFalse := filg.DefineLabel;
    filg.Emit(Opcodes.Brfalse, lFalse);
    EmitElement(el.True);
    filg.MarkLabel(lFalse);
  end else if el.True = nil then begin
    PushExpression(el.ExpressionElement);
    filg.Emit(Opcodes.Call, Utilities.method_GetObjAsBoolean);
    var lTrue := filg.DefineLabel;
    filg.Emit(Opcodes.Brtrue, lTrue);
    EmitElement(el.FAlse);
    filg.MarkLabel(lTrue);
  end else begin
    PushExpression(el.ExpressionElement);
    filg.Emit(Opcodes.Call, Utilities.method_GetObjAsBoolean);
    var lFalse := filg.DefineLabel;
    filg.Emit(Opcodes.Brfalse, lFalse);
    EmitElement(el.True);
    var lExit := filg.DefineLabel;
    filg.Emit(Opcodes.Br, lExit);
    filg.MarkLabel(lFalse);
    EmitElement(el.False);
    fILG.MarkLabel(lExit);
  end;
end;

method EcmaScriptCompiler.WriteDoStatement(el: DoStatement);
begin

end;

method EcmaScriptCompiler.WriteWhileStatement(el: WhileStatement);
begin
end;

method EcmaScriptCompiler.WriteForStatement(el: ForStatement);
begin
end;

method EcmaScriptCompiler.WriteForInstatement(el: ForInStatement);
begin
end;

method EcmaScriptCompiler.WriteContinue(el: ContinueStatement);
begin
end;

method EcmaScriptCompiler.WriteBreak(el: BreakStatement);
begin
end;

method EcmaScriptCompiler.WriteLabelled(aLabel: LabelledStatement);
begin

end;

end.