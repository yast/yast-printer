/*
 * YaST2: Core system
 *
 * Description:
 *   YaST2 SCR: Printerdb agent implementation
 *
 * Authors:
 *   Petr Blahos <pblahos@suse.cz>
 *
 * $Id$
 */

#ifndef Y2PrinterdbAgentComponent_h
#define Y2PrinterdbAgentComponent_h

#include "Y2.h"

class SCRInterpreter;
class PrinterdbAgent;


class Y2PrinterdbAgentComponent : public Y2Component
{
    private:
        SCRInterpreter *interpreter;
        PrinterdbAgent *agent;
    
    public:
    
        /**
         * Default constructor
         */
        Y2PrinterdbAgentComponent();
        
        /**
         * Destructor
         */
        ~Y2PrinterdbAgentComponent();
        
        /**
         * Returns true: The scr is a server component
         */
        bool isServer() const;
        
        /**
         * Returns the name of the module.
         */
        virtual string name() const;
        
        /**
         * Starts the server, if it is not already started and does
         * what a server is good for: Gets a command, evaluates (or
         * executes) it and returns the result.
         * @param command The command to be executed. Any YCPValueRep
         * can be executed. The execution is performed by some
         * YCPInterpreter.
         */
        virtual YCPValue evaluate(const YCPValue& command);
};

#endif
