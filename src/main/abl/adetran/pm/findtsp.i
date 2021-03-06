/*********************************************************************
* Copyright (C) 2000,2020 by Progress Software Corporation. All      *
* rights reserved. Prior versions of this work may contain portions  *
* contributed by participants of Possenet.                           *
*                                                                    *
*********************************************************************/
/*

Procedure:    adetran/pm/findtsp.i
Author:       SLK
Created:      09/98
Updated:      
Purpose:      Translation Manager's find include file
Background:   Include file for locating NEXT Translation records 
              (see comments in pm/_find.w).
Called By:    pm/_find.w
Usage:        {adetran/pm/findtsp.i SourcePhrase PREV}
NOTE:         This code is different from VT's _find.i because
              xlatedb.xl_string_info.original_string is setup as a
              case-sensitive string therefore the "=" will FAIL.
              We need to lc values before comparison .

For readability we'll leave the action (NEXT,LAST,LAST etc.)
{1} Type of Phrase = SourcePhrase or TargetPhrase
{2} NEXT, LAST, LAST, ...

OLD 1=xlatedb.xlatedb.XL_Instance, sourphrase next

PREV
   FIND CURRENT xl_string_info
   FIND PREV XL_Instance
   IF NOT AVAILABLE XL_Instance THEN
     FIND PREV xl_string_info
     IF AVAILABLE xl_string_info THEN
        FIND LAST XL_Instance
     ELSE 
        MESSAGE "Begin at the top"
        FIND LAST button. LEAVE.
   FIND LAST XL_Translation
*/


IF IgnoreSpaces:CHECKED THEN 
DO:
   IF MatchCase:CHECKED THEN 
   DO:
      IF UseWildCards:CHECKED THEN 
      DO:
         FIND PREV xlatedb.XL_Instance WHERE 
            xlatedb.XL_Instance.sequence_num = xlatedb.XL_String_Info.sequence_num 
         NO-LOCK NO-ERROR.
         IF NOT AVAILABLE xlatedb.XL_Instance THEN
         DO:
            FIND PREV xlatedb.XL_String_Info WHERE 
               TRIM(xlatedb.XL_String_Info.original_string) MATCHES TRIM(tVal)
            NO-LOCK NO-ERROR.
            ASSIGN ErrorStatus = NO.
            IF NOT AVAILABLE xlatedb.XL_String_Info THEN
            DO:
               ASSIGN 
                  ThisMessage = "Search Item Was Not Found. Start search from " 
                              + "last record?".
               RUN adecomm/_s-alert.p (INPUT-OUTPUT ErrorStatus,"q*":U,"yes-no",ThisMessage).
            END. /* NOT AVAILABLE XL_String_Info */
            IF ErrorStatus THEN 
            DO:
               {adetran/pm/findtsrc.i SourcePhrase LAST}
            END. /* ErrorStatus */
            ELSE
            DO:
               FIND LAST xlatedb.XL_Instance WHERE
                  xlatedb.XL_Instance.sequence_num = xlatedb.XL_String_Info.sequence_num
               NO-LOCK NO-ERROR.
               FIND LAST xlatedb.XL_Translation WHERE
                      xlatedb.XL_Instance.sequence_num = xlatedb.XL_Translation.sequence_num
                  AND xlatedb.XL_Instance.instance_num = xlatedb.XL_Translation.instance_num
               NO-LOCK NO-ERROR.
            END. /* NOT ErrorStatus */
         END. /* NOT AVAILABLE XL_Instance */
      END.  /* UseWildCards */
      ELSE 
      DO: /* NOT WildCards */
         FIND PREV xlatedb.XL_Instance WHERE 
            xlatedb.XL_Instance.sequence_num = xlatedb.XL_String_Info.sequence_num 
         NO-LOCK NO-ERROR.
         IF NOT AVAILABLE xlatedb.XL_Instance THEN
         DO:
            FIND PREV xlatedb.XL_String_Info WHERE 
               TRIM(xlatedb.XL_String_Info.original_string) = TRIM(tVal)
            NO-LOCK NO-ERROR.
            ASSIGN ErrorStatus = NO.
            IF NOT AVAILABLE xlatedb.XL_String_Info THEN
            DO:
               ASSIGN 
                  ThisMessage = "Search Item Was Not Found. Start search from " 
                              + "last record?".
               RUN adecomm/_s-alert.p (INPUT-OUTPUT ErrorStatus,"q*":U,"yes-no",ThisMessage).
            END. /* NOT AVAILABLE XL_String_Info */
            IF ErrorStatus THEN 
            DO:
               {adetran/pm/findtsrc.i SourcePhrase LAST}
            END. /* ErrorStatus */
            ELSE
            DO:
               FIND LAST xlatedb.XL_Instance WHERE 
                  xlatedb.XL_Instance.sequence_num = xlatedb.XL_String_Info.sequence_num 
               NO-LOCK NO-ERROR.
               FIND LAST xlatedb.XL_Translation WHERE 
                      xlatedb.XL_Instance.sequence_num = xlatedb.XL_Translation.sequence_num 
                  AND xlatedb.XL_Instance.instance_num = xlatedb.XL_Translation.instance_num 
               NO-LOCK NO-ERROR.
            END. /* NOT ErrorStatus */
         END. /* NOT AVAILABLE XL_Instance */
      END.  /* NOT UseWildCards */
   END. /* MatchCase */
   ELSE 
   DO: /* Not Case sensitive */
      IF UseWildCards:CHECKED THEN 
      DO:
         FIND PREV xlatedb.XL_Instance WHERE 
            xlatedb.XL_Instance.sequence_num = xlatedb.XL_String_Info.sequence_num 
         NO-LOCK NO-ERROR.
         IF NOT AVAILABLE xlatedb.XL_Instance THEN
         DO:
            FIND PREV xlatedb.XL_String_Info WHERE 
               TRIM(LC(xlatedb.XL_String_Info.original_string)) MATCHES TRIM(LC(FindValue))
            NO-LOCK NO-ERROR.
            ASSIGN ErrorStatus = NO.
            IF NOT AVAILABLE xlatedb.XL_String_Info THEN
            DO:
               ASSIGN 
                  ThisMessage = "Search Item Was Not Found. Start search from " 
                              + "last record?".
               RUN adecomm/_s-alert.p (INPUT-OUTPUT ErrorStatus,"q*":U,"yes-no",ThisMessage).
            END. /* NOT AVAILABLE XL_String_Info */
            IF ErrorStatus THEN 
            DO:
                {adetran/pm/findtsrc.i SourcePhrase LAST}
            END. /* ErrorStatus */
            ELSE
            DO:   
               FIND LAST xlatedb.XL_Instance WHERE 
                  xlatedb.XL_Instance.sequence_num = xlatedb.XL_String_Info.sequence_num 
               NO-LOCK NO-ERROR.
               FIND LAST xlatedb.XL_Translation WHERE 
                      xlatedb.XL_Instance.sequence_num = xlatedb.XL_Translation.sequence_num 
                  AND xlatedb.XL_Instance.instance_num = xlatedb.XL_Translation.instance_num 
               NO-LOCK NO-ERROR.
            END. /* NOT ErrorStatus */
         END. /* NOT AVAILABLE XL_Instance */
      END. /* WildCards */
      ELSE
      DO:
         FIND PREV xlatedb.XL_Instance WHERE 
                   xlatedb.XL_Instance.sequence_num = xlatedb.XL_String_Info.sequence_num 
         NO-LOCK NO-ERROR.
         IF NOT AVAILABLE xlatedb.XL_Instance THEN
         DO:
            FIND PREV xlatedb.XL_String_Info WHERE 
               TRIM(LC(xlatedb.XL_String_Info.original_string)) = TRIM(LC(FindValue))
            NO-LOCK NO-ERROR.
            ASSIGN ErrorStatus = NO.
            IF NOT AVAILABLE xlatedb.XL_String_Info THEN
            DO:
               ASSIGN 
                  ThisMessage = "Search Item Was Not Found. Start search from " 
                              + "last record?".
               RUN adecomm/_s-alert.p (INPUT-OUTPUT ErrorStatus,"q*":U,"yes-no",ThisMessage).
            END. /* NOT AVAILABLE XL_String_Info */
            IF ErrorStatus THEN 
            DO:
                           {adetran/pm/findtsrc.i SourcePhrase LAST}
            END. /* ErrorStatus */
            ELSE
            DO:  
               FIND LAST xlatedb.XL_Instance WHERE 
                  xlatedb.XL_Instance.sequence_num = xlatedb.XL_String_Info.sequence_num 
               NO-LOCK NO-ERROR.
               FIND LAST xlatedb.XL_Translation WHERE 
                      xlatedb.XL_Instance.sequence_num = xlatedb.XL_Translation.sequence_num 
                  AND xlatedb.XL_Instance.instance_num = xlatedb.XL_Translation.instance_num 
               NO-LOCK NO-ERROR.
           END. /* NOT ErrorStatus */
       END. /* NOT AVAILABLE XL_Instance */
    END. /* Not Wildcards */
  END. /* Not Case sensitive */
END.  /* IF ignore spaces */
ELSE
DO: /* Don't ignore spaces */
   IF MatchCase:CHECKED THEN 
   DO:
      IF UseWildCards:CHECKED THEN 
      DO:
         FIND PREV xlatedb.XL_Instance WHERE 
               xlatedb.XL_Instance.sequence_num = xlatedb.XL_String_Info.sequence_num 
         NO-LOCK NO-ERROR.
         IF NOT AVAILABLE xlatedb.XL_Instance THEN
         DO:
            FIND PREV xlatedb.XL_String_Info WHERE 
               xlatedb.XL_String_Info.original_string MATCHES tVal
            NO-LOCK NO-ERROR.
            ASSIGN ErrorStatus = NO.
            IF NOT AVAILABLE xlatedb.XL_String_Info THEN
            DO:
               ASSIGN 
                  ThisMessage = "Search Item Was Not Found. Start search from " 
                              + "last record?".
               RUN adecomm/_s-alert.p (INPUT-OUTPUT ErrorStatus,"q*":U,"yes-no",ThisMessage).
            END. /* NOT AVAILABLE XL_String_Info */
            IF ErrorStatus THEN 
            DO:
               {adetran/pm/findtsrc.i SourcePhrase LAST}
            END. /* ErrorStatus */
            ELSE
            DO:  
               FIND LAST xlatedb.XL_Instance WHERE 
                  xlatedb.XL_Instance.sequence_num = xlatedb.XL_String_Info.sequence_num 
               NO-LOCK NO-ERROR.
               FIND LAST xlatedb.XL_Translation WHERE 
                      xlatedb.XL_Instance.sequence_num = xlatedb.XL_Translation.sequence_num 
                  AND xlatedb.XL_Instance.instance_num = xlatedb.XL_Translation.instance_num 
               NO-LOCK NO-ERROR.
            END. /* NOT ErrorStatus */
         END. /* NOT AVAILABLE XL_Instance */
      END. /* WildCards */
      ELSE
      DO:
         FIND PREV xlatedb.XL_Instance WHERE 
            xlatedb.XL_Instance.sequence_num = xlatedb.XL_String_Info.sequence_num 
         NO-LOCK NO-ERROR.
         IF NOT AVAILABLE xlatedb.XL_Instance THEN
         DO:
            FIND PREV xlatedb.XL_String_Info WHERE 
               xlatedb.XL_String_Info.original_string = tVal
            NO-LOCK NO-ERROR.
            ASSIGN ErrorStatus = NO.
            IF NOT AVAILABLE xlatedb.XL_String_Info THEN
            DO:
               ASSIGN 
                  ThisMessage = "Search Item Was Not Found. Start search from " 
                              + "last record?".
               RUN adecomm/_s-alert.p (INPUT-OUTPUT ErrorStatus,"q*":U,"yes-no",ThisMessage).
            END. /* NOT AVAILABLE XL_String_Info */
            IF ErrorStatus THEN 
            DO:
               {adetran/pm/findtsrc.i SourcePhrase LAST}
            END. /* ErrorStatus */
            ELSE
            DO:   
               FIND LAST xlatedb.XL_Instance WHERE 
                  xlatedb.XL_Instance.sequence_num = xlatedb.XL_String_Info.sequence_num 
               NO-LOCK NO-ERROR.
               FIND LAST xlatedb.XL_Instance WHERE 
                      xlatedb.XL_Instance.sequence_num = xlatedb.XL_Translation.sequence_num 
                  AND xlatedb.XL_Instance.instance_num = xlatedb.XL_Translation.instance_num 
               NO-LOCK NO-ERROR.
            END. /* NOT ErrorStatus */
         END. /* NOT AVAILABLE XL_Instance */
      END. /* Widlcard */
   END. /* MatchCase */
   ELSE 
   DO: /* Not Case sensitive */
      IF UseWildCards:CHECKED THEN 
      DO:
         FIND PREV xlatedb.XL_Instance WHERE 
            xlatedb.XL_Instance.sequence_num = xlatedb.XL_String_Info.sequence_num 
         NO-LOCK NO-ERROR.
         IF NOT AVAILABLE xlatedb.XL_Instance THEN
         DO:
            FIND PREV xlatedb.XL_String_Info WHERE 
               LC(xlatedb.XL_String_Info.original_string) MATCHES LC(FindValue)
            NO-LOCK NO-ERROR.
            ASSIGN ErrorStatus = NO.
            IF NOT AVAILABLE xlatedb.XL_String_Info THEN
            DO:
               ASSIGN 
                  ThisMessage = "Search Item Was Not Found. Start search from " 
                              + "last record?".
               RUN adecomm/_s-alert.p (INPUT-OUTPUT ErrorStatus,"q*":U,"yes-no",ThisMessage).
            END. /* NOT AVAILABLE XL_String_Info */
            IF ErrorStatus THEN 
            DO:
               {adetran/pm/findtsrc.i SourcePhrase LAST}
            END. /* ErrorStatus */
            ELSE
            DO:  
               FIND LAST xlatedb.XL_Instance WHERE 
                  xlatedb.XL_Instance.sequence_num = xlatedb.XL_String_Info.sequence_num 
               NO-LOCK NO-ERROR.
               FIND LAST xlatedb.XL_Translation WHERE 
                      xlatedb.XL_Instance.sequence_num = xlatedb.XL_Translation.sequence_num 
                  AND xlatedb.XL_Instance.instance_num = xlatedb.XL_Translation.instance_num 
               NO-LOCK NO-ERROR.
            END. /* NOT ErrorStatus */
         END. /* NOT AVAILABLE XL_Instance */
      END. /* Wildcard */
      ELSE
      DO:
         FIND PREV xlatedb.XL_Instance WHERE 
            xlatedb.XL_Instance.sequence_num = xlatedb.XL_String_Info.sequence_num 
         NO-LOCK NO-ERROR.
         IF NOT AVAILABLE xlatedb.XL_Instance THEN
         DO:
            FIND PREV xlatedb.XL_String_Info WHERE 
               LC(xlatedb.XL_String_Info.original_string) = LC(FindValue)
            NO-LOCK NO-ERROR.
            ASSIGN ErrorStatus = NO.
            IF NOT AVAILABLE xlatedb.XL_String_Info THEN
            DO:
               ASSIGN 
                  ThisMessage = "Search Item Was Not Found. Start search from " 
                              + "last record?".
               RUN adecomm/_s-alert.p (INPUT-OUTPUT ErrorStatus,"q*":U,"yes-no",ThisMessage).
            END. /* NOT AVAILABLE XL_String_Info */
            IF ErrorStatus THEN 
            DO:
               {adetran/pm/findtsrc.i SourcePhrase LAST}
            END.
            ELSE
            DO:  
               FIND LAST xlatedb.XL_Instance WHERE 
                        xlatedb.XL_Instance.sequence_num = xlatedb.XL_String_Info.sequence_num 
               NO-LOCK NO-ERROR.
               FIND LAST xlatedb.XL_Translation WHERE 
                            xlatedb.XL_Instance.sequence_num = xlatedb.XL_Translation.sequence_num 
                        AND xlatedb.XL_Instance.instance_num = xlatedb.XL_Translation.instance_num 
               NO-LOCK NO-ERROR.
            END. /* NOT ErrorStatus */
         END. /* NOT AVAILABLE XL_Instance */
      END. /* Wildcard */
   END. /* Not Case sensitive */
END. /* Don't ignore spaces */
