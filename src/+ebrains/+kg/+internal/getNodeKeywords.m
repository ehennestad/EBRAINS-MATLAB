function varargout = getNodeKeywords(node, keywords)

    arguments
        node (1,1) struct
    end
    arguments (Repeating)
        keywords (1,1) string
    end

    % Matlab will replace the @ used for jsonld keywords with x_,
    % e.g @id -> x_id
    keywords = "x_" + string(keywords);

    numKeywords = numel(keywords);
    varargout = cell(1, numKeywords);
    for i = 1:numKeywords
        if isfield(node, keywords(i))
            varargout{i} = node.(keywords(i));
        else
            varargout{i} = '';
        end
    end
end
