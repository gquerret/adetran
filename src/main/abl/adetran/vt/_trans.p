/*********************************************************************
* Copyright (C) 2005,2020 by Progress Software Corporation. All      *
* reserved.  Prior versions of this work may contain portions        *
* contributed by participants of Possenet.                           *
*                                                                    *
*********************************************************************/
/*

Procedure:    adetran/vt/_trans.p
Author:       F. Chang/R. Ryan
Created:      1/95
Updated:      9/95
		11/96 SLK Long FileName
		03/97 SLK Bug# 97-03-07-082 when order translation columns
		because 2 columns had the same column name
Purpose:      Visual Translator's Translation tab procedure
Background:   This is a persistent procedure that is run from
              vt/_main.p *only* after a database is connected.
              Once connected, this procedure controls the browser
              associated with the edit-mode translation functions.
Notes:        Mostly, the editable browser does most of the work:
              editing/updating of cell contents.  The ROW-LEAVE
              event checks to see if this item has been included
              in the glossary - if not, it adds it to the glossary
              table.  A double-click event brings up the glossary
              window.  A translator can also visualize a procedure
              from this mode (i.e. a resource file exists *and* the
              object type is appropriate).
Procedures:   Key procedures include:

                DeleteRow      deletes a row(s)
                SetRow         evaluates and adds the source/target
                               entry to the glossary.
                OrderColumn    dynamic logic for computing the columns
                               in the translation browser that will be
                               used by the 'Order Columns' functionality
                               found in hMain.
                CreateOrdList  works with above.
                SortQuery      logic for sorting the query based upon
                               the 'Sort' functionality called in hMain.
                Ref            refreshes the browse
                Repo           repositions the row

Called By:    vt/_main.p
*/

{ adetran/vt/vthlp.i } /* definitions for help context strings */
DEFINE SHARED VARIABLE hLkUp        AS HANDLE            NO-UNDO.
DEFINE SHARED VARIABLE CurrentTool  AS CHARACTER         NO-UNDO.
DEFINE SHARED VARIABLE hLongStr     AS HANDLE            NO-UNDO.
DEFINE SHARED VARIABLE hSort        AS HANDLE            NO-UNDO.
DEFINE SHARED VARIABLE hTrans       AS HANDLE            NO-UNDO.
DEFINE SHARED VARIABLE MainWindow   AS HANDLE            NO-UNDO.
DEFINE SHARED VARIABLE tPrevh       AS HANDLE            NO-UNDO.
DEFINE SHARED VARIABLE Priv1        AS LOGICAL           NO-UNDO.
DEFINE SHARED VARIABLE Priv2        AS LOGICAL           NO-UNDO.
DEFINE SHARED VARIABLE Priv3        AS LOGICAL           NO-UNDO.
DEFINE SHARED VARIABLE hResource    AS HANDLE            NO-UNDO.
DEFINE SHARED VARIABLE tModFlag     AS LOGICAL           NO-UNDO.
DEFINE SHARED VARIABLE OrdMode2     AS CHARACTER         NO-UNDO.
DEFINE SHARED VARIABLE tInstRec     AS RECID             NO-UNDO.
DEFINE SHARED VARIABLE FullPathFlag AS LOGICAL           NO-UNDO.
DEFINE SHARED VARIABLE hMain        AS HANDLE            NO-UNDO.
DEFINE SHARED VARIABLE ConfirmAdds  AS LOGICAL           NO-UNDO.
DEFINE SHARED VARIABLE hGloss       AS HANDLE            NO-UNDO.
DEFINE SHARED VARIABLE hFind        AS HANDLE            NO-UNDO.
DEFINE SHARED VARIABLE hReplace     AS HANDLE            NO-UNDO.

/* Temporary files generated by _sort.w and _order.w.                */
/* If these are blank then the regular OpenQuery internal procedures */
/* are run, otherwise these will be run                              */
DEFINE SHARED VARIABLE TmpFl_VT_Tr  AS CHARACTER         NO-UNDO.

DEFINE VARIABLE result        AS LOGICAL                 NO-UNDO.
DEFINE VARIABLE i             AS INTEGER                 NO-UNDO.
DEFINE VARIABLE ThisMessage   AS CHARACTER               NO-UNDO.
DEFINE VARIABLE ErrorStatus   AS LOGICAL                 NO-UNDO.
DEFINE VARIABLE NewTrans      AS LOGICAL                 NO-UNDO.
DEFINE VARIABLE tLog          AS LOGICAL                 NO-UNDO.
DEFINE VARIABLE tSav          AS CHARACTER               NO-UNDO.
DEFINE VARIABLE ColSearchOn   AS LOGICAL                 NO-UNDO.
DEFINE VARIABLE ColSearchHdl  AS HANDLE                  NO-UNDO.
DEFINE VARIABLE ColSearchType AS CHARACTER               NO-UNDO.
DEFINE VARIABLE ThisBufferFileName AS CHARACTER          NO-UNDO.

DEFINE TEMP-TABLE tmp-order
  FIELD OrdCol AS CHARACTER
  FIELD OldNum AS INTEGER
  FIELD NewNum AS INTEGER.

&Scoped-define FRAME-NAME  TransFrame
&Scoped-define BROWSE-NAME ThisBuffer

DEFINE NEW SHARED BUFFER ThisString FOR kit.XL_instance.
DEFINE NEW SHARED QUERY  ThisBuffer FOR ThisString SCROLLING.

DEFINE BROWSE ThisBuffer QUERY ThisBuffer
  DISPLAY
    ThisString.SourcePhrase COLUMN-LABEL "Source!Phrase" WIDTH 30 FORMAT "X(256)":U
    ThisString.TargetPhrase COLUMN-LABEL "Target!Phrase" WIDTH 30 FORMAT "X(256)":U
    (IF FullPathFlag THEN ThisString.ProcedureName ELSE
    SUBSTRING(ThisString.ProcedureName, r-index(ThisString.ProcedureName,"\":U) + 1,
               -1,"CHARACTER":U))
    @ ThisBufferFileName
    FORMAT "x(256)":U
    WIDTH 30 COLUMN-LABEL "Procedure!Name"
    ThisString.UpdateDate COLUMN-LABEL "Last!Updated" WIDTH 10
    ThisString.ProcedureName FORMAT "x(256)" WIDTH 30 COLUMN-LABEL "Procedure!Name (Scrollable)"
    ThisString.MaxLength COLUMN-LABEL "!Length" WIDTH 8
  ENABLE
    ThisString.SourcePhrase ThisString.TargetPhrase
    ThisString.ProcedureName
  WITH NO-ASSIGN EXPANDABLE MULTIPLE SEPARATORS SIZE-PIXELS 602 BY 299 FONT 4.

DEFINE FRAME TransFrame
  ThisBuffer AT ROW 1 COL 1
  WITH 1 DOWN NO-BOX KEEP-TAB-ORDER OVERLAY SIDE-LABELS NO-UNDERLINE THREE-D
       AT X 14 Y 52 SIZE-PIXELS 602 BY 299 FONT 4.

/* **********************  Triggers  *********************** */

on help of frame TransFrame do:
  run adecomm/_adehelp.p ("vt":U,"context":U,{&Translations_Tab_Folder}, ?).    
end.

ON ANY-KEY OF ThisString.SourcePhrase IN BROWSE ThisBuffer DO:
  /* This trigger allows scrolling but not editing */
  IF NOT CAN-DO("CURSOR-*,END,HOME,TAB,BACK-TAB":U,KEYLABEL(LASTKEY))
  THEN RETURN NO-APPLY.
END.

ON ANY-KEY OF ThisString.ProcedureName IN BROWSE ThisBuffer DO:
  /* This trigger allows scrolling but not editing */
  IF NOT CAN-DO("CURSOR-*,END,HOME,TAB,BACK-TAB":U,KEYLABEL(LASTKEY))
  THEN RETURN NO-APPLY.
END.

on value-changed of ThisBuffer in frame {&Frame-Name} do: 
  IF AVAILABLE ThisString THEN DO:
    tInstRec = recid(ThisString).
    RUN Refresh IN hLongStr (INPUT ThisString.SourcePhrase,
                             INPUT ThisString.TargetPhrase,
                             INPUT hTrans).
    /* Tell Find Dialog to reposition itself */
    IF VALID-HANDLE(hFind) THEN
      RUN FndRec IN hFind (INPUT ROWID(ThisString), INPUT "kit.XL_Instance").
    /* Tell Replace Dialog to reposition itself */
    IF VALID-HANDLE(hReplace) THEN
      RUN FndRec IN hReplace (INPUT ROWID(ThisString), INPUT "kit.XL_Instance").
  END.
end.

on entry of browse thisbuffer do:
   run CustSensi in hMain(ThisBuffer:handle in frame {&frame-name}).
end.

on leave of ThisBuffer in frame {&frame-name} do: 
  tPrevh = last-event:widget-leave.
end.

on row-entry of ThisBuffer in frame {&Frame-Name} do: 
  RUN disableUpdate IN hMain.  /* Disable delete button/menu-item */
  /* Record may have been changed by another user in multi-user mode... */
  FIND CURRENT ThisString NO-LOCK NO-ERROR.              
  IF AVAILABLE ThisString AND ThisBuffer:NUM-SELECTED-ROWS GT 0 THEN DO:
    DISPLAY ThisString.TargetPhrase WITH BROWSE ThisBuffer.
    tSav = ThisString.TargetPhrase:Screen-value in browse ThisBuffer. 
  END.
end.     

on row-leave of ThisBuffer in frame {&Frame-Name} do:
  IF NOT ThisString.TargetPhrase:MODIFIED IN BROWSE ThisBuffer THEN
    RETURN.

  DO TRANSACTION:
    GET CURRENT ThisBuffer EXCLUSIVE-LOCK NO-WAIT.
    IF LOCKED ThisString THEN DO:
      ThisMessage = "This string is locked by another user":U.

      GET CURRENT ThisBuffer NO-LOCK.
      RUN adecomm/_setcurs.p ("WAIT":U).
      FIND FIRST kit._Lock WHERE _Lock-RecID = INTEGER(RECID(ThisString)) 
                         AND (_Lock-Flags = "X":U OR  /* Exclusive-lock */
                              _Lock-Flags = "S":U OR  /* Share-lock     */
                              _Lock-Flags = "U":U)    /* Upgraded lock  */
        NO-LOCK NO-ERROR.
      IF AVAILABLE kit._Lock THEN DO:
        ASSIGN ThisMessage = REPLACE(ThisMessage, "another user":U, _Lock-Name).
        FIND FIRST kit._Connect WHERE _Connect-Usr = _Lock-Usr NO-LOCK NO-ERROR.
        IF AVAILABLE kit._Connect THEN
          ThisMessage = ThisMessage + " on device: ":U + _Connect-Device.
      END.

      RUN adecomm/_setcurs.p ("":U).
      RUN adecomm/_s-alert.p (INPUT-OUTPUT ErrorStatus, "w*":U, "ok":U, ThisMessage). 
    END.  /* ThisBuffer is locked */
    ELSE IF CURRENT-CHANGED(ThisString) THEN DO:
      ThisMessage = REPLACE("The Target Phrase has been changed since you began working on it.  The new value is ~"&1~".  Do you still want to save your changes?":U, "&1":U, ThisString.TargetPhrase).
      RUN adecomm/_s-alert.p (INPUT-OUTPUT ErrorStatus, "q":U, "yes-no":U, ThisMessage). 
      IF ErrorStatus /* i.e., user selected "yes" */ THEN DO:
        ASSIGN INPUT BROWSE ThisBuffer ThisString.TargetPhrase.
        RUN SetRow.
      END.  /* Save changes */
      ELSE DISPLAY ThisString.TargetPhrase WITH BROWSE ThisBuffer.  /* Update browser row */
    END.  /* Record was changed by another user */
    ELSE DO:
      ASSIGN INPUT BROWSE ThisBuffer ThisString.TargetPhrase.
      RUN SetRow.
    END.  /* Record was locked successfully */
  END. /*Transaction */

  GET CURRENT ThisBuffer NO-LOCK.  /* Downgrade lock */
  FIND CURRENT kit.XL_Project NO-LOCK NO-ERROR.
  RUN SetSensitivity IN hMain.  /* Re-enable delete button/menu-item */
end.

on mouse-select-dblclick of frame {&frame-name} anywhere do:
  RUN DisplayGlossary.
  RUN Realize IN hLongStr (INPUT ThisString.SourcePhrase,
                           INPUT ThisString.TargetPhrase,
                           INPUT hTrans).
end.

ON START-SEARCH OF ThisBuffer IN FRAME {&FRAME-NAME}
DO:
  ColSearchOn = Yes.
  ColSearchHdl = ThisBuffer:CURRENT-COLUMN.
  CASE ColSearchHdl:LABEL:
    WHEN "Source!Phrase":u OR WHEN "Target!Phrase":u THEN
    DO:
       ColSearchType = SUBSTRING(ColSearchHdl:LABEL, 1, 1, "CHARACTER":U).
    END.
    
    OTHERWISE
    DO:
      ColSearchType = "":u.
      IF NOT CAN-DO("ThisBufferFileName,ProcedureName":u , ColSearchHdl:NAME) THEN
      DO:
        ColSearchOn = No.
        APPLY "END-SEARCH":u TO BROWSE ThisBuffer.
      END.
    END.
  END CASE.
END.  

ON END-SEARCH OF ThisBuffer IN FRAME {&FRAME-NAME}
DO:
  ColSearchOn = No.
  ColSearchType = "":u.
END.

ON ANY-PRINTABLE OF ThisBuffer IN FRAME {&FRAME-NAME}
DO:
  DEFINE VARIABLE proc-name AS CHARACTER NO-UNDO.
  DEFINE VARIABLE found-one AS LOGICAL   NO-UNDO.
    
  IF NOT ColSearchOn OR NOT VALID-HANDLE(hFind) THEN RETURN.
  
  /* Perform special column searching. */   
  IF ColSearchType <> "":u THEN
  DO:
    RUN SetColSearch IN hFind (INPUT ColSearchType, INPUT LAST-EVENT:LABEL).
    RUN StartColSearch IN hFind.
    /* RUN FindNextTran.ip IN hFind. */
  END.
  ELSE
  DO:
    RUN adecomm/_setcurs.p ("WAIT":U).
    col-search-blk:
    DO WHILE TRUE:
      GET NEXT ThisBuffer.
      IF QUERY-OFF-END("ThisBuffer":u) THEN
      DO:
        /* Go back to most recent current column. */
        IF tInstRec <> ? THEN RUN Repo (tInstRec , ?).
        LEAVE col-search-blk.
      END.
      IF ColSearchHdl:NAME = "ThisBufferFileName":u THEN
      DO:

        proc-name = (IF FullPathFlag THEN ThisString.ProcedureName ELSE
                     SUBSTRING(ThisString.ProcedureName,
                               r-index(ThisString.ProcedureName,"\":U) + 1, -1,"CHARACTER":U)).
        found-one = (proc-name BEGINS LAST-EVENT:LABEL).
      END.
      ELSE IF ColSearchHdl:NAME = "ProcedureName":u THEN
        found-one = (ThisString.ProcedureName BEGINS LAST-EVENT:LABEL).

      IF found-one THEN
      DO:
        IF AVAILABLE ThisString THEN
        DO:
          RUN Repo in hTrans (INPUT RECID(ThisString), INPUT 0).
          tInstRec = RECID(ThisString).
        END.
        LEAVE col-search-blk.
      END.  /* IF found-one */
    END. /* DO WHILE TRUE - col-search-blk */
    RUN adecomm/_setcurs.p ("":U).
  END.

END.

/* ***************************  Main Block  *************************** */

{adetran/common/noscroll.i}

pause 0 before-hide.

main-block:
do on error   undo main-block, leave main-block
   on end-key undo main-block, leave main-block:

  thisbuffer:num-locked-columns = 1.
  run openquery.
  
  if not THIS-PROCEDURE:persistent then
    wait-for close of THIS-PROCEDURE.
end.
{adecomm/_adetool.i}

 
/* **********************  Internal procedures  *********************** */

PROCEDURE DeleteRow :     
  if ThisBuffer:num-selected-rows in frame {&frame-name} < 1 then do:
    ThisMessage = "You must select a row first.".
    run adecomm/_s-alert.p (input-output ErrorStatus, "w":U,"ok":U, ThisMessage). 
    return.
  end.

  ThisMessage = "Delete selected rows?".
  run adecomm/_s-alert.p (input-output ErrorStatus, "q*":U, "yes-no":U, ThisMessage).    
  if not ErrorStatus then return.
                  
  run adecomm/_setcurs.p ("wait":U).
  do with frame TransFrame TRANSACTION:
    do i = ThisBuffer:num-selected-rows to 1 by -1:    
      result = ThisBuffer:fetch-selected-row(i).    

      GET CURRENT ThisBuffer EXCLUSIVE-LOCK NO-WAIT.
      IF LOCKED ThisString THEN DO:
        ThisMessage = "This string is locked by another user":U.

        GET CURRENT ThisBuffer NO-LOCK.
        RUN adecomm/_setcurs.p ("WAIT":U).
        FIND FIRST kit._Lock WHERE _Lock-RecID = INTEGER(RECID(ThisString)) 
                           AND (_Lock-Flags = "X":U OR  /* Exclusive-lock */
                                _Lock-Flags = "S":U OR  /* Share-lock     */
                                _Lock-Flags = "U":U)    /* Upgraded lock  */
          NO-LOCK NO-ERROR.
        IF AVAILABLE kit._Lock THEN DO:
          ASSIGN ThisMessage = REPLACE(ThisMessage, "another user":U, _Lock-Name).
          FIND FIRST kit._Connect WHERE _Connect-Usr = _Lock-Usr NO-LOCK NO-ERROR.
          IF AVAILABLE kit._Connect THEN
            ThisMessage = ThisMessage + " on device: ":U + _Connect-Device.
        END.

        RUN adecomm/_setcurs.p ("":U).
        RUN adecomm/_s-alert.p (INPUT-OUTPUT ErrorStatus, "w*":U, "ok":U, ThisMessage).
        UNDO, RETURN.  /* Abort all deletes */
      END.  /* ThisBuffer is locked */
      ELSE DO:
        DELETE ThisString. 
      END.
    end.  
  
    result = ThisBuffer:delete-selected-rows().
    tModFlag = true.
  end.      
  
  run SetSensitivity in hMain.
  run adecomm/_setcurs.p ("":U).      
END PROCEDURE.


PROCEDURE SetRow:    
  DEFINE VARIABLE bs_pos  AS INTEGER                          NO-UNDO.
  DEFINE VARIABLE ss      AS CHARACTER                        NO-UNDO.
  DEFINE VARIABLE st      AS CHARACTER                        NO-UNDO.
  DEFINE VARIABLE tmpdir  AS CHARACTER                        NO-UNDO.
  DEFINE VARIABLE tmpfln  AS CHARACTER                        NO-UNDO.

  do with frame {&frame-name} TRANSACTION:
    if not ThisString.targetPhrase:modified in browse ThisBuffer then return.         
   
    if can-find(kit.xl_invalid where kit.xl_Invalid.TargetPhrase MATCHES
      ThisString.TargetPhrase:screen-value in browse ThisBuffer) then do: 
    
      ThisMessage = "This Translation Is Invalid.".
      run adecomm/_s-alert.p (input-output ErrorStatus, "w*":U, "ok":U, ThisMessage).    
    
      ThisString.TargetPhrase:screen-value in browse ThisBuffer = "":U.
      return.
    end. 

    ASSIGN ss = replace(ThisString.SourcePhrase:screen-value in browse ThisBuffer,"~&":U,"":U)
           st = replace(ThisString.TargetPhrase:screen-value in browse ThisBuffer,"~&":U,"":U)
           NewTrans             = (ThisString.ShortTarg = "":U)
           ThisString.ShortTarg = SUBSTRING(st, 1, 63, "RAW":U)
           ss = trim(ss)
           st = trim(st).
           
    find first kit.XL_GlossEntry where
          kit.XL_GlossEntry.ShortSrc     BEGINS SUBSTRING(ss, 1, 63, "RAW":U) and
          kit.XL_GlossEntry.ShortTarg    BEGINS SUBSTRING(st, 1, 63, "RAW":U) and
          COMPARE(kit.XL_GlossEntry.SourcePhrase, "=":U, ss, "CAPS":U) and
          COMPARE(kit.XL_GlossEntry.TargetPhrase, "=":U, st, "CAPS":U) 
      EXCLUSIVE-LOCK NO-ERROR. 
    
    if not avail kit.XL_GlossEntry and not locked kit.XL_GlossEntry then do:                          
      if ConfirmAdds then do:
        ThisMessage = "Do you want to update the glossary?".
        run adecomm/_s-alert.p (input-output Result, "q":U, "yes-no":U, ThisMessage).    
      end.
      else Result = true.    
         
      if Result then do:
        create kit.XL_GlossEntry.
        assign
          kit.XL_GlossEntry.SourcePhrase         = ss
          kit.XL_GlossEntry.TargetPhrase         = st
          kit.XL_GlossEntry.ShortSrc             = SUBSTRING(ss, 1, 63, "RAW":U)
          kit.XL_GlossEntry.ShortTarg            = SUBSTRING(st, 1, 63, "RAW":U)
          kit.XL_GlossEntry.ModifiedByTranslator = true
          kit.XL_GlossEntry.GlossaryType         = "C":U.
         
        run OpenQuery in hGloss. /* Redisplay updated glossary in VT window */
      end.  /* If Result */
    end.  /* If not available xl_GlossEntry */

    if (tSav = "":U) and  /* Target Phrase was blank upon entering the row */
       (ThisString.TargetPhrase:screen-value in browse ThisBuffer <> "":U) then do:
      find first kit.XL_Project EXCLUSIVE-LOCK no-error.
      if avail kit.XL_Project AND NewTrans then DO:
        assign
          kit.XL_Project.TranslationCount = kit.XL_Project.TranslationCount + 1
          tModFlag                        = true.
      END.
    end.  /* A line has been translated */   
    else if (tSav <> "":U) and 
       (ThisString.TargetPhrase:screen-value in browse ThisBuffer = "":U) then do:
      find first kit.XL_Project EXCLUSIVE-LOCK no-error.
      if avail kit.XL_Project then DO:
        assign
          kit.XL_Project.TranslationCount = kit.XL_Project.TranslationCount - 1
          tModFlag                        = true.
      END.
    end.  /* A line has been untranslated */
    
    ASSIGN bs_pos = R-INDEX(ThisString.ProcedureName,"\":U)
           tmpdir = IF bs_pos GT 0 THEN
                      SUBSTRING(ThisString.ProcedureName, 1, bs_pos - 1, "CHARACTER":U)
                    ELSE
                      ".":U
           tmpfln = SUBSTRING(ThisString.ProcedureName, bs_pos + 1, -1, "CHARACTER":U).
    FIND kit.XL_Procedure WHERE kit.XL_Procedure.Directory  = tmpdir AND
                                kit.XL_Procedure.Filename   = tmpfln
                           EXCLUSIVE-LOCK NO-ERROR.
    IF AVAIlABLE kit.XL_Procedure THEN 
      ASSIGN kit.XL_Procedure.Modified = YES.
  end.  /* DO with frame {&FRAME-NAME} TRANSACTION */

  /* Downgrade lock statuses on records we updated */
  FIND CURRENT kit.XL_GlossEntry NO-LOCK NO-ERROR.
  FIND CURRENT kit.XL_Project    NO-LOCK NO-ERROR.
  FIND CURRENT kit.XL_Procedure  NO-LOCK NO-ERROR.
END PROCEDURE.

PROCEDURE disable_UI :
  hide frame TransFrame.
  if THIS-PROCEDURE:PERSISTENT then delete PROCEDURE THIS-PROCEDURE.
END PROCEDURE.

PROCEDURE Goto:
    /* Repositions Translations Tab browse to the top or bottom row. */
    DEFINE INPUT PARAMETER gotoFlag         AS CHARACTER NO-UNDO.

    IF NOT BROWSE ThisBuffer:SENSITIVE THEN RETURN.
    
    CASE gotoFlag:
      WHEN 'TOP':u THEN
        APPLY 'HOME':u TO BROWSE ThisBuffer.
           
      WHEN 'BOTTOM':u THEN
        APPLY 'END':u TO BROWSE ThisBuffer.
    END CASE.

END PROCEDURE.

PROCEDURE HideMe :
  frame TransFrame:hidden = true.
END PROCEDURE.

PROCEDURE OpenQuery :
  do with frame {&frame-name}:
    IF TmpFl_VT_Tr NE "":U THEN RUN VALUE(TmpFl_VT_Tr).
    ELSE DO:
      OPEN QUERY ThisBuffer FOR EACH ThisString NO-LOCK INDEXED-REPOSITION.
    END.
    
    FIND FIRST kit.XL_Project NO-LOCK NO-ERROR.
    if available kit.XL_Project and kit.XL_Project.NumberOfPhrases > 0 then 
      ThisBuffer:max-data-guess = kit.XL_Project.NumberOfPhrases.
   
    if OrdMode2 = "":U then run CreateOrdList. 
  end.
END PROCEDURE.

PROCEDURE Realize :
  enable all with frame TransFrame in window MainWindow. 
  if Priv1 then /* MustuseGlossary */
     assign ThisString.TargetPhrase:read-only in browse ThisBuffer = yes.
  else      
  if not priv2 then /* SuperSedeGlossary */
     assign ThisString.TargetPhrase:read-only in browse ThisBuffer = yes.
  frame TransFrame:hidden = false.
END PROCEDURE.

PROCEDURE Ref :
   DEFINE INPUT PARAMETER pRecid AS RECID NO-UNDO.
   
   tLog = ThisBuffer:REFRESH() IN FRAME {&Frame-Name}.
   if pRecid <> ? then                                                                         
   DO: 
      tlog = ThisBuffer:set-repositioned-row(INTEGER(ThisBuffer:num-iterations / 2),
                                                     "CONDITIONAL":U) in frame {&frame-name}.
      REPOSITION ThisBuffer TO recid pRECID NO-ERROR.
   end.   

   /* Tell Find Dialog to reposition itself */
   IF VALID-HANDLE(hFind) THEN
     RUN FndRec IN hFind (INPUT ROWID(ThisString), INPUT "kit.XL_Instance").
   /* Tell Replace Dialog to reposition itself */
   IF VALID-HANDLE(hReplace) THEN
     RUN FndRec IN hReplace (INPUT ROWID(ThisString), INPUT "kit.XL_Instance").
END PROCEDURE.

PROCEDURE Repo :
   DEFINE INPUT PARAMETER pRecid AS RECID NO-UNDO.
   DEFINE INPUT PARAMETER pRow AS INTEGER NO-UNDO.
                                         
   IF pRecid = ? THEN
      REPOSITION ThisBuffer TO ROW pRow.
   ELSE                                                
   DO: 
      tlog = ThisBuffer:set-repositioned-row(INTEGER(ThisBuffer:num-iterations / 2),
                                                     "CONDITIONAL":U) in frame {&frame-name}.
      REPOSITION ThisBuffer TO RECID pRECID.
      /* REPOSITION ThisBuffer TO RECID pRECID NO-ERROR. */
   END.

   /* Tell Find Dialog to reposition itself */
   IF VALID-HANDLE(hFind) THEN
     RUN FndRec IN hFind (INPUT ROWID(ThisString), INPUT "kit.XL_Instance").
   /* Tell Replace Dialog to reposition itself */
   IF VALID-HANDLE(hReplace) THEN
     RUN FndRec IN hReplace (INPUT ROWID(ThisString), INPUT "kit.XL_Instance").
END PROCEDURE.


PROCEDURE SortQuery :
  define input parameter pTempFile AS CHARACTER NO-UNDO.  
  DEFINE VARIABLE hBrCol AS HANDLE NO-UNDO.

  IF pTempFile NE TmpFl_VT_Tr THEN DO:
    IF TmpFl_VT_Tr NE "":U THEN OS-DELETE VALUE(TmpFl_VT_Tr).
    TmpFl_VT_Tr = pTempFile.
  END.

  /* In case we are updating the browse, commit the change before reopening query */
  hBrCol = ThisBuffer:CURRENT-COLUMN IN FRAME {&FRAME-NAME}.
  IF VALID-HANDLE(hBrCol) THEN DO:
    APPLY "LEAVE" TO hBrCol.
    APPLY "ROW-LEAVE" TO ThisBuffer IN FRAME {&FRAME-NAME}.
  END.

  if valid-handle(hSort) then delete PROCEDURE hSort.  
  run value(pTempFile) persistent set hSort. 
  if valid-handle(hSort) then hSort:private-data = CurrentTool.

  find first kit.XL_Project NO-LOCK no-error.
  if available kit.XL_Project and kit.XL_Project.NumberOfPhrases > 0 then 
    ThisBuffer:max-data-guess IN FRAME {&FRAME-NAME} = kit.XL_Project.NumberOfPhrases.

  /* Tell Find Dialog to reposition itself */
  IF VALID-HANDLE(hFind) THEN
    RUN FndRec IN hFind (INPUT ROWID(ThisString), INPUT "kit.XL_Instance").
  /* Tell Replace Dialog to reposition itself */
  IF VALID-HANDLE(hReplace) THEN
    RUN FndRec IN hReplace (INPUT ROWID(ThisString), INPUT "kit.XL_Instance").
END PROCEDURE.

PROCEDURE OrderColumn :
  {adetran/common/_order.i ThisBuffer}    
END PROCEDURE.

PROCEDURE DisplayGlossary:
  RUN Realize IN hLKup (ThisString.SourcePhrase, ThisString.TargetPhrase).
END PROCEDURE.

PROCEDURE UpdateInstance:  
  define input parameter pTarValue AS CHARACTER NO-UNDO.

  DO TRANSACTION:
    GET CURRENT ThisBuffer EXCLUSIVE-LOCK NO-WAIT.
    IF LOCKED ThisString THEN DO:
      ThisMessage = "This string is locked by another user":U.

      GET CURRENT ThisBuffer NO-LOCK.
      RUN adecomm/_setcurs.p ("WAIT":U).
      FIND FIRST kit._Lock WHERE _Lock-RecID = INTEGER(RECID(ThisString)) 
                         AND (_Lock-Flags = "X":U OR  /* Exclusive-lock */
                              _Lock-Flags = "S":U OR  /* Share-lock     */
                              _Lock-Flags = "U":U)    /* Upgraded lock  */
        NO-LOCK NO-ERROR.
      IF AVAILABLE kit._Lock THEN DO:
        ASSIGN ThisMessage = REPLACE(ThisMessage, "another user":U, _Lock-Name).
        FIND FIRST kit._Connect WHERE _Connect-Usr = _Lock-Usr NO-LOCK NO-ERROR.
        IF AVAILABLE kit._Connect THEN
          ThisMessage = ThisMessage + " on device: ":U + _Connect-Device.
      END.

      RUN adecomm/_setcurs.p ("":U).
      RUN adecomm/_s-alert.p (INPUT-OUTPUT ErrorStatus, "w*":U, "ok":U, ThisMessage). 
    END.  /* ThisBuffer is locked */
    ELSE IF CURRENT-CHANGED(ThisString) THEN DO:
      ThisMessage = REPLACE("The Target Phrase has been changed since you began working on it.  The new value is ~"&1~".  Do you still want to save your changes?":U, "&1":U, ThisString.TargetPhrase).
      RUN adecomm/_s-alert.p (INPUT-OUTPUT ErrorStatus, "q":U, "yes-no":U, ThisMessage). 
      IF ErrorStatus /* i.e., user selected "yes" */ THEN DO:
        ASSIGN ThisString.TargetPhrase = pTarValue 
               NewTrans                = (ThisString.ShortTarg = "":U)
               ThisString.ShortTarg    = SUBSTRING(ThisString.TargetPhrase,1,63,"RAW":U)
               ThisString.TargetPhrase:screen-value in browse ThisBuffer = pTarValue.
        if ThisString.ShortTarg = ? THEN ThisString.ShortTarg = "":U.
        FIND FIRST kit.XL_Project EXCLUSIVE-LOCK NO-ERROR.
        IF AVAILABLE kit.XL_Project THEN DO:
          IF NewTrans AND ThisString.ShortTarg NE "":U THEN
            kit.XL_Project.TranslationCount = kit.XL_Project.TranslationCount + 1.
          ELSE IF NOT NewTrans AND ThisString.ShortTarg = "":U THEN
            kit.XL_Project.TranslationCount = kit.XL_Project.TranslationCount - 1.
        END.  /* If  available XL_Project */

        RUN Refresh IN hLongStr (INPUT ThisString.SourcePhrase,
                                 INPUT ThisString.TargetPhrase,
                                 INPUT hTrans).
      END.  /* Save changes */
      ELSE DISPLAY ThisString.TargetPhrase WITH BROWSE ThisBuffer.  /* Update browser row */
    END.  /* Record was changed by another user */
    ELSE DO:
      ASSIGN ThisString.TargetPhrase = pTarValue 
             NewTrans                = (ThisString.ShortTarg = "":U)
             ThisString.ShortTarg    = SUBSTRING(ThisString.TargetPhrase,1,63,"RAW":U)
             ThisString.TargetPhrase:screen-value in browse ThisBuffer = pTarValue.
      if ThisString.ShortTarg = ? THEN ThisString.ShortTarg = "":U.
      FIND FIRST kit.XL_Project EXCLUSIVE-LOCK NO-ERROR.
      IF AVAILABLE kit.XL_Project THEN DO:
        IF NewTrans AND ThisString.ShortTarg NE "":U THEN
          kit.XL_Project.TranslationCount = kit.XL_Project.TranslationCount + 1.
        ELSE IF NOT NewTrans AND ThisString.ShortTarg = "":U THEN
          kit.XL_Project.TranslationCount = kit.XL_Project.TranslationCount - 1.
      END.  /* If  available XL_Project */

      RUN Refresh IN hLongStr (INPUT ThisString.SourcePhrase,
                               INPUT ThisString.TargetPhrase,
                               INPUT hTrans).
    END.  /* Record was locked successfully */
  END. /*Transaction */

  GET CURRENT ThisBuffer NO-LOCK.  /* Downgrade lock */
  FIND CURRENT kit.XL_Project NO-LOCK NO-ERROR.
END PROCEDURE.   

PROCEDURE Viewprocedure:
  DEFINE VARIABLE bs-pos    AS INTEGER  NO-UNDO.
  DEFINE VARIABLE ThisProc       AS CHARACTER     NO-UNDO.  
  DEFINE VARIABLE hWin           AS HANDLE   NO-UNDO.   
  DEFINE VARIABLE RootDir        AS CHARACTER     NO-UNDO.
  DEFINE VARIABLE Dir            AS CHARACTER     NO-UNDO.
  DEFINE VARIABLE ResourceFile   AS CHARACTER     NO-UNDO.     
  DEFINE VARIABLE RcodeFile      AS CHARACTER     NO-UNDO.
  DEFINE VARIABLE BackupFile     AS CHARACTER     NO-UNDO.
  DEFINE VARIABLE File_Name      AS CHARACTER     NO-UNDO.
  DEFINE VARIABLE ErrorStatus    AS LOGICAL  NO-UNDO.  

  if not 
    can-do("DEF-BUTTON,DEF-BROWSE,DEF-FRAME,DEF-MENU,DEF-SUB-MENU,MESSAGE,DISPLAY,FORM,VIEW-AS":U,
    ThisString.Statement) then do:
    ThisMessage = ThisString.SourcePhrase + "^Is a " + ThisString.Statement +
                 " statment and cannot be viewed.".
    run adecomm/_s-alert.p (input-output ErrorStatus, "w*":U, "ok":U, ThisMessage).    
    return.
  end.   
  else if ThisString.statement = "MESSAGE":U then do:
    if ThisString.TargetPhrase:screen-value in browse ThisBuffer <> "":U then do:
      ThisMessage = ThisString.TargetPhrase:screen-value in browse ThisBuffer.
      run adecomm/_s-alert.p (input-output ErrorStatus, "m*":U, "ok":U, ThisMessage).    
      return. 
    end.
    else do:
      ThisMessage = ThisString.SourcePhrase.
      run adecomm/_s-alert.p (input-output ErrorStatus, "m*":U, "ok":U, ThisMessage).    
      return.
    end.
  end.
  else do: 
    find first kit.XL_Project NO-LOCK no-error.
    if available kit.XL_Project then
      RootDir = kit.XL_Project.RootDirectory. 
      
   ASSIGN bs-pos = R-INDEX(ThisString.ProcedureName,"\":U)
          DIR    = SUBSTRING(ThisString.ProcedureName,1,bs-pos - 1,"CHARACTER":U)
          File_Name = SUBSTRING(ThisString.ProcedureName, bs-pos + 1, -1,"character":U).

    run adecomm/_osfmush.p (input Dir , input File_Name, output ResourceFile).  
    run adecomm/_osfmush.p (input RootDir , input ResourceFile, output ResourceFile).
    run adecomm/_osfmush.p (input Dir , input File_Name, output ThisProc).  

    assign ResourceFile = entry(1,ResourceFile,".":U) + ".rc":U.
      
    run Evaluateprocedure in hMain (input ThisProc, output hWin, output ErrorStatus).
        
    if ErrorStatus then do:  
      run realize in hWin.
      return.
    end.           

    assign file-info:filename = entry(1,ThisProc,".":U) + ".r":U
           RcodeFile          = file-info:full-pathname
           BackupFile         = entry(1,RCodeFile,".":U) + ".bak":U.

    if RCodefile <> ? then do:
      os-copy value(RCodeFile) value(BackupFile).
      os-delete value (RCodeFile) no-error. 
    end.

    do on stop undo, next:
      run value(ResourceFile) persistent set hResource.
      if valid-handle(hResource) then hResource:private-data = CurrentTool.
      run CreateWindows in hMain (input hResource).      
    end.

    if RCodeFile <> ? then do:
      os-copy value(BackupFile) value(RcodeFile).
      os-delete value(BackupFile).
    end.
    
    run adecomm/_setcurs.p ("":U).   
  end.
end.  

PROCEDURE EvaluateGloss:
  define output parameter pStatus AS LOGICAL NO-UNDO. 
  do with frame TransFrame: 
    if ThisBuffer:num-selected-rows >= 1 then pStatus = true.
  end.
END PROCEDURE.    

PROCEDURE CreateOrdList :
  DEFINE VARIABLE tBrColWH     as widget-handle NO-UNDO.
  DEFINE VARIABLE tListItems   AS CHARACTER NO-UNDO.

  DO WITH FRAME {&frame-name}:
    ASSIGN tBrColWH = ThisBuffer:First-Column
           tListItems = "":U.
                   
    DO WHILE tBrColWH <> ?:  
      ASSIGN tListItems = tListItems + ",":U +  tBrColWh:LABEL                                   
             tBrColWH = tBrColWH:Next-Column.
    END.
               
    ASSIGN tListItems = TRIM(tListItems,",":U)
           tListItems = REPLACE(tListItems,"!":U,"":U)
           OrdMode2 = tListItems.
  END. /* DO WITH FRAME */     
END PROCEDURE. /* CreateOrdList */ 


PROCEDURE Store-Long-String:
  DEFINE INPUT PARAMETER src AS CHARACTER               NO-UNDO.
  DEFINE INPUT PARAMETER trg AS CHARACTER               NO-UNDO.
  
  /* First make sure that we are still on the correct row of the browse  */
  IF ThisString.SourcePhrase NE src THEN RETURN.
  IF trg = ? THEN RETURN.

  DO TRANSACTION ON ERROR UNDO, LEAVE:
    GET CURRENT ThisBuffer EXCLUSIVE-LOCK NO-WAIT.
    IF LOCKED ThisString THEN DO:
      ThisMessage = "This string is locked by another user":U.

      GET CURRENT ThisBuffer NO-LOCK.
      RUN adecomm/_setcurs.p ("WAIT":U).
      FIND FIRST kit._Lock WHERE _Lock-RecID = INTEGER(RECID(ThisString)) 
                         AND (_Lock-Flags = "X":U OR  /* Exclusive-lock */
                              _Lock-Flags = "S":U OR  /* Share-lock     */
                              _Lock-Flags = "U":U)    /* Upgraded lock  */
        NO-LOCK NO-ERROR.
      IF AVAILABLE kit._Lock THEN DO:
        ASSIGN ThisMessage = REPLACE(ThisMessage, "another user":U, _Lock-Name).
        FIND FIRST kit._Connect WHERE _Connect-Usr = _Lock-Usr NO-LOCK NO-ERROR.
        IF AVAILABLE kit._Connect THEN
          ThisMessage = ThisMessage + " on device: ":U + _Connect-Device.
      END.

      RUN adecomm/_setcurs.p ("":U).
      RUN adecomm/_s-alert.p (INPUT-OUTPUT ErrorStatus, "w":U, "ok":U, ThisMessage). 
    END.  /* ThisBuffer is locked */
    ELSE IF CURRENT-CHANGED(ThisString) THEN DO:
      ThisMessage = REPLACE("The Target Phrase has been changed since you began working on it.  The new value is ~"&1~".  Do you still want to save your changes?":U, "&1":U, ThisString.TargetPhrase).
      RUN adecomm/_s-alert.p (INPUT-OUTPUT ErrorStatus, "q":U, "yes-no":U, ThisMessage). 
      IF ErrorStatus /* i.e., user selected "yes" */ THEN DO:
        ASSIGN ThisString.TargetPhrase = trg
               ThisString.TargetPhrase:SCREEN-VALUE IN BROWSE ThisBuffer = trg
               ThisString.ShortTarg    = SUBSTRING(trg, 1, 63, "RAW":U).
        RUN SetRow.
      END.  /* Save Changes */
      ELSE DISPLAY ThisString.TargetPhrase WITH BROWSE ThisBuffer.  /* Update browser row */
    END.  /* Record was changed by another user */
    ELSE DO:
      ASSIGN ThisString.TargetPhrase = trg
             ThisString.TargetPhrase:SCREEN-VALUE IN BROWSE ThisBuffer = trg
             ThisString.ShortTarg    = SUBSTRING(trg, 1, 63, "RAW":U).
      RUN SetRow.
    END.  /* Record was locked successfully */
  END.  /* TRANSACTION */
  
  GET CURRENT ThisBuffer NO-LOCK.  /* Downgrade lock */
END PROCEDURE. /* Store-Long-String */
