function fgPropName = validateFgPropName(fgPropName, fgObject)
    propNames = properties( fgObject );

    pluralWord = findPluralWord(propNames, fgPropName);

    if ~isempty(pluralWord)
        fgPropName = pluralWord;
    end
end

function pluralWord = findPluralWord(wordList, singularWord)
    % Initialize the output as empty
    pluralWord = '';
    
    % Simple pluralization rules for common cases
    pluralRules = {
        @(w) [w 's'], ...                    % e.g., cat -> cats
        @(w) [w(1:end-1) 'ies'], ...          % e.g., baby -> babies
        @(w) [w 'es'], ...                    % e.g., bush -> bushes
    };
    
    % Loop through each word in the list
    for i = 1:length(wordList)
        word = wordList{i};
        
        % Check if the current word matches any plural form of the singular word
        for rule = pluralRules
            if strcmp(word, rule{1}(singularWord))
                pluralWord = word;
                return;
            end
        end
    end
end
