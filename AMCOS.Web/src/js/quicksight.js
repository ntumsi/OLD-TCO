

const embedDashboard = async (embedURL) => {
    
    const embeddingContext = await QuickSightEmbedding.createEmbeddingContext({
        onChange: (changeEvent, metadata) => {
            console.log('Context received a change', changeEvent, metadata);
        },
    });
    const frameOptions = {
        url: embedURL, 
        container: '#embeddedQuickSightContent',
        onChange: (changeEvent, metadata) => {
            console.log(changeEvent.eventName); 
        },
    };
    const contentOptions = {
        onMessage: async (messageEvent, experienceMetadata) => {
            console.log(messageEvent.eventName); 
        }
    };
    //This embeds the visual to the container element.
    const embeddedConsoleExperience = await embeddingContext.embedDashboard(frameOptions, contentOptions);
};


